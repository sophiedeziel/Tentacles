# typed: true
# frozen_string_literal: true

class Printer < ApplicationRecord
  extend T::Sig

  # Seconds to wait for OctoPrint when uploading G-code files
  UPLOAD_OPEN_TIMEOUT = 5
  UPLOAD_TIMEOUT = 120

  has_many :jobs, class_name: 'Printer::Job', dependent: :nullify
  has_many :dashboard_widgets, dependent: :destroy

  validates :name, presence: true

  def current_job
    jobs.find_by(status: 'active') || using_api do
      data = Octoprint::Job.get
      # Missing job info raises here and falls through to the rescue below (=> nil)
      file = T.must(T.must(data.information).file)
      {
        name: file[:name],
        progress: T.must(T.must(data.progress).completion).round(1)
      }
    end
  rescue StandardError
    nil
  end

  def self.table_name_prefix
    return '' if self == Printer

    'printer_'
  end

  def octoprint_version
    using_api(cache: 2.hours) do
      Octoprint::ServerVersion.get
    end
  end

  def job_status
    using_api do
      Octoprint::Job.get.state
    end
  end

  def jobs_count
    jobs.where(status: 'enqueued').count
  end

  # Errors (including timeouts) are raised to the caller: an upload must not fail silently, nor mark the printer
  # as disconnected, so this doesn't go through using_api and its cache.
  sig { params(file: String, options: T.untyped).returns(Octoprint::Files::OperationResult) }
  def upload(file, options: {})
    upload_client.use do
      Octoprint::Files.upload(file, **options)
    end
  end

  def using_api(cache: false, &)
    method = T.must(T.must(caller[0])[/'.*'/])[1..-2]
    OctoprintCache.use_cache(id:, method:, time: cache) do
      api_client.use(&)
    end
  rescue Octoprint::Exceptions::ConnectionError => e
    Rails.logger.error("Failed to get OctoPrint data for #{name} :\n\t#{e.message}")
    OctoprintCache.set_disconnected(id)
    nil
  end

  def queue
    jobs.where(status: 'enqueued').order(created_at: :asc, id: :asc)
  end

  def next_job
    queue.first
  end

  def update_subscribers
    TentaclesSchema.subscriptions.trigger(:printer_subscription, { id: }, {})
  end

  def start_print
    REDIS_POOL.with do |conn|
      conn.publish('printers', { command: :start_print, printer_id: id }.to_json)
    end
  end

  # The printer's own OctoPrint client, for `printer.octoprint_client.use { Octoprint::Job.get }`.
  # `use` sets the client for the current thread only: the gem's global configuration is never touched.
  # Raises Octoprint::Exceptions::MissingCredentialsError when the URI or the API key is blank.
  #
  # Rebuilt when the URI or the API key changed (e.g. after a `reload` in the long-lived spooler).
  sig { returns(Octoprint::Client) }
  def octoprint_client
    credentials = [octoprint_uri.presence, octoprint_key.presence]
    client = @octoprint_client
    return client if client && @octoprint_client_credentials == credentials

    client = Octoprint::Client.new(host: credentials[0], api_key: credentials[1]) # Raises before anything is cached
    @octoprint_client_credentials = T.let(credentials, T.nilable(T::Array[T.nilable(String)]))
    @octoprint_client = T.let(client, T.nilable(Octoprint::Client))
    client
  end

  # Why the next job of the queue can't be started, or nil when it can: the printer must be OPERATIONAL, with
  # something in its queue and no active job. The single rule behind Printer.canStartNext and startNextPrint.
  #
  #   Printer.start_next_blocker(state_family: PrinterStateFamily::Printing, enqueued: true, active: false)
  #   # => :not_ready
  sig do
    params(state_family: PrinterStateFamily, enqueued: T::Boolean, active: T::Boolean).returns(T.nilable(Symbol))
  end
  def self.start_next_blocker(state_family:, enqueued:, active:)
    return :active_job if active
    return :empty_queue unless enqueued
    return :not_ready unless state_family == PrinterStateFamily::Operational

    nil
  end

  sig { params(state_family: PrinterStateFamily, enqueued: T::Boolean, active: T::Boolean).returns(T::Boolean) }
  def self.start_next_allowed?(state_family:, enqueued:, active:)
    start_next_blocker(state_family:, enqueued:, active:).nil?
  end

  private

  def api_client
    @api_client ||= Octoprint::Client.new(host: octoprint_uri, api_key: octoprint_key)
  end

  # Large G-code files take much longer to upload than the API client's 3 seconds read timeout
  def upload_client
    @upload_client ||= Octoprint::Client.new(host: octoprint_uri, api_key: octoprint_key,
                                             open_timeout: UPLOAD_OPEN_TIMEOUT, timeout: UPLOAD_TIMEOUT)
  end
end
