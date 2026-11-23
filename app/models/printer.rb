# typed: true
# frozen_string_literal: true

class Printer < ApplicationRecord
  # 'octoprint', 'prusalink': see Printer::Backend::ADAPTERS
  BACKENDS = Printer::Backend::ADAPTERS.keys.freeze #: Array[String]

  # delete_all: a single DELETE. Nothing is pushed per job: Printer::Removal pushes printQueueChanged once.
  has_many :jobs, class_name: 'Printer::Job', dependent: :delete_all
  has_many :dashboard_widgets, class_name: 'Dashboard::Widget', dependent: :destroy

  include EncryptedSecret
  include Specs
  include Filaments

  validates :name, presence: true
  validates :backend, inclusion: { in: BACKENDS }
  # Printers saved before `uri` and `secret` existed may lack them: the monitor reports their missing credentials
  validates :uri, :secret, presence: true, on: :create

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

  # e.g. "OctoPrint 1.11.2" or "PrusaLink 2.1.2 (firmware 6.1.3)", cached for 2 hours
  def version
    using_api(cache: 2.hours) do
      api.version
    end
  end

  def job_status
    using_api do
      api.job_status
    end
  end

  def jobs_count
    jobs.enqueued.count
  end

  # Runs the block (which calls #api) unless the printer was found unreachable in the last 10 minutes (see
  # Printer::Disconnection), caching its result according to `cache` (see Printer::ApiCache.find_or_create_by):
  # - a duration: the cached answer, else the block's result, cached for that long
  # - false (the default): the cached answer, else the block's result, which isn't cached
  # - nil: the block's result, without reading the cache
  # Returns nil, and remembers it for 10 minutes, when the printer can't be reached. Returns nil too when the stored
  # secret can't be decrypted. Other errors are raised. An unsaved printer is never cached nor marked disconnected.
  def using_api(cache: false, &)
    return yield if new_record? # Nothing to key the cache with
    return log_disconnected if Disconnection.exists?(printer_id: id)
    return yield if cache.nil?

    api_method = api_method_of(caller_locations(1, 1))
    ApiCache.find_or_create_by(printer_id: id, api_method:, expires_in: cache, &).value
  rescue Printer::Backend::Unreachable, Printer::Backend::UnreadableCredentials => e
    api_unavailable(e)
  end

  def queue
    jobs.enqueued.in_queue_order
  end

  def next_job
    queue.first
  end

  # Pushes printerStatusChanged, whose subscribers get this printer, after a change they show (e.g. its loaded
  # filament). The change is saved by then: a push that fails is logged, never raised, and only leaves the other
  # windows behind until their next refresh. (Printer::Status pushes its own snapshot, and lets its errors through.)
  #: -> void
  def push_status_changed
    TentaclesSchema.subscriptions.trigger(:printer_status_changed, {}, self)
  rescue StandardError => e
    Rails.logger.error("[Printer] Could not push printerStatusChanged for printer #{id}: #{e.class}: #{e.message}")
  end

  def update_subscribers
    TentaclesSchema.subscriptions.trigger(:printer_subscription, { id: }, {})
  end

  # Publishes a command for this printer to the spooler (lib/spooler.rb), e.g. Printer::SpoolerCommand::StartPrint
  #: (Printer::SpoolerCommand command) -> void
  def notify_spooler(command)
    REDIS_POOL.with { |conn| conn.publish('printers', { command: command.serialize, printer_id: id }.to_json) }
  end

  # The printer's API adapter (see Printer::Backend): `printer.api.pause`, `printer.api.state_family`, ...
  # The adapter holds the printer's own clients: the client gems' global configuration is never touched.
  #
  # Rebuilt when the backend or the credentials changed (e.g. after a `reload` in the long-lived spooler).
  #: -> Printer::Backend
  def api
    credentials = api_credentials
    adapter = @api
    return adapter if adapter && @api_credentials == credentials

    adapter = Printer::Backend.for(self)
    @api_credentials = credentials #: Array[String?]?
    @api = adapter #: Printer::Backend?
    adapter
  end

  # What the API adapter is built from: when they change, so does the adapter (and the monitor's worker)
  #: -> Array[String?]
  def api_credentials
    [backend, uri, username, readable_secret]
  end

  # Why the next job of the queue can't be started, or nil when it can: the printer must be OPERATIONAL, with
  # something in its queue and no active job. The single rule behind Printer.canStartNext and startNextPrint.
  #
  #   Printer.start_next_blocker(state_family: Printer::StateFamily::Printing, enqueued: true, active: false)
  #   # => :not_ready
  #: (
  #|   state_family: Printer::StateFamily,
  #|   enqueued: bool,
  #|   active: bool
  #| ) -> Symbol?
  def self.start_next_blocker(state_family:, enqueued:, active:)
    return :active_job if active
    return :empty_queue unless enqueued
    return :not_ready unless state_family == Printer::StateFamily::Operational

    nil
  end

  #: (state_family: Printer::StateFamily, enqueued: bool, active: bool) -> bool
  def self.start_next_allowed?(state_family:, enqueued:, active:)
    start_next_blocker(state_family:, enqueued:, active:).nil?
  end

  private

  #: -> NilClass
  def log_disconnected = nil.tap { Rails.logger.info("Printer #{id} is disconnected, not calling API") }

  # The name of the method that called #using_api (e.g. "Printer#version"), under which its answers are cached. From
  # the caller's location, as this method's own caller would be sorbet-runtime's wrapper.
  #: (Array[Thread::Backtrace::Location]? locations) -> String
  def api_method_of(locations) = locations&.first&.label #: as !nil

  #: (Printer::Backend::Error error) -> NilClass
  def api_unavailable(error)
    Rails.logger.error("Failed to get #{api.product_name} data for #{name} :\n\t#{error.message}")
    Disconnection.create!(printer_id: id) if persisted? && error.is_a?(Printer::Backend::Unreachable)
    nil
  end
end
