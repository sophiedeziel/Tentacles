# typed: true
# frozen_string_literal: true

class Printer < ApplicationRecord
  extend T::Sig

  BACKENDS = %w[octoprint prusalink].freeze

  # delete_all, not destroy: Printers::Remove pushes printQueueChanged once instead of once per job
  has_many :jobs, class_name: 'Printer::Job', dependent: :delete_all
  has_many :dashboard_widgets, dependent: :destroy

  include EncryptedSecret
  include Specs

  validates :name, presence: true
  validates :backend, inclusion: { in: BACKENDS }
  # Printers saved before `uri` and `secret` existed may lack them: the monitor reports their missing credentials
  validates :uri, :secret, presence: true, on: :create

  # Keeps the old columns in sync until they are dropped, so that the previous release still works after a rollback
  before_save :mirror_octoprint_credentials

  # The job under way: the active job of the queue, or the job the printer reports (`{ name:, progress: }`).
  # nil when there is none or when it can't be read.
  def current_job
    jobs.find_by(status: 'active') || using_api do
      job = api.current_job
      job&.merge(progress: job[:progress].round(1))
    end
  rescue StandardError
    nil
  end

  def self.table_name_prefix
    return '' if self == Printer

    'printer_'
  end

  # e.g. "OctoPrint 1.11.2", cached for 2 hours
  def version
    using_api(cache: 2.hours) do
      api.version
    end
  end
  alias octoprint_version version

  def job_status
    using_api do
      api.job_status
    end
  end

  def jobs_count
    jobs.enqueued.count
  end

  # Errors (including timeouts) are raised to the caller: an upload must not fail silently, nor mark the printer
  # as disconnected, so this doesn't go through using_api and its cache.
  sig { params(path: String, print: T::Boolean).void }
  def upload(path, print: false)
    api.upload(path, print:)
  end

  # Runs the block (which calls #api) unless the printer was found unreachable in the last 10 minutes, caching its
  # result for `cache` seconds. Returns nil, and remembers it for 10 minutes, when the printer can't be reached.
  # Returns nil too when the stored secret can't be decrypted. Other errors are raised.
  def using_api(cache: false, &)
    method = T.must(T.must(caller[0])[/'.*'/])[1..-2]
    PrinterApiCache.use_cache(id:, method:, time: cache, &)
  rescue PrinterBackends::Unreachable, PrinterBackends::UnreadableCredentials => e
    api_unavailable(e)
  end

  def queue
    jobs.enqueued.in_queue_order
  end

  def next_job
    queue.first
  end

  def update_subscribers
    TentaclesSchema.subscriptions.trigger(:printer_subscription, { id: }, {})
  end

  # Publishes a command for this printer to the spooler (lib/spooler.rb): start_print, add_printer, remove_printer
  sig { params(command: Symbol).void }
  def notify_spooler(command)
    REDIS_POOL.with { |conn| conn.publish('printers', { command:, printer_id: id }.to_json) }
  end

  # The printer's API adapter (see PrinterBackends::Base): `printer.api.pause`, `printer.api.state_family`, ...
  # The adapter holds the printer's own clients: the client gems' global configuration is never touched.
  #
  # Rebuilt when the backend or the credentials changed (e.g. after a `reload` in the long-lived spooler).
  sig { returns(PrinterBackends::Base) }
  def api
    credentials = api_credentials
    adapter = @api
    return adapter if adapter && @api_credentials == credentials

    adapter = PrinterBackends.for(self)
    @api_credentials = T.let(credentials, T.nilable(T::Array[T.nilable(String)]))
    @api = T.let(adapter, T.nilable(PrinterBackends::Base))
    adapter
  end

  # What the API adapter is built from: when they change, so does the adapter (and the monitor's worker)
  sig { returns(T::Array[T.nilable(String)]) }
  def api_credentials
    [backend, uri, username, readable_secret]
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

  sig { params(error: PrinterBackends::Error).returns(NilClass) }
  def api_unavailable(error)
    Rails.logger.error("Failed to get #{api.product_name} data for #{name} :\n\t#{error.message}")
    PrinterApiCache.set_disconnected(id) if error.is_a?(PrinterBackends::Unreachable)
    nil
  end

  # Until the cleanup drops them, `octoprint_uri` and `octoprint_key` mirror `uri` and `secret`. A blank or unreadable
  # value never erases the old one: the previous release would lose credentials it could still use.
  sig { void }
  def mirror_octoprint_credentials
    return unless backend == 'octoprint'

    self.octoprint_uri = uri if uri.present?
    key = readable_secret
    self.octoprint_key = key if key.present?
  end
end
