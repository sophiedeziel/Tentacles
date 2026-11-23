# typed: true
# frozen_string_literal: true

class Printer
  module Monitor
    # Polls one printer's API (OctoPrint, PrusaLink) in its own thread and publishes its Printer::Status when its state
    # changes.
    #
    # Every tick reloads the status through the printer's Reader (see Printer::Status#reload) and saves it, which
    # stores it in Redis and notifies the GraphQL subscribers, only when it changed (see Printer::Status#changed?).
    # Unreachable printers are reported as OFFLINE and polled less and less often (see Connectivity#delay).
    # The first time the printer answers, its blank specs are filled in the background unless a fill already read its
    # server (see #fill_specs_once).
    #
    #   worker = Printer::Monitor::Worker.new(printer:).start
    #   worker.stop
    #   worker.join
    #
    # The status, reader, webcam tracker and connectivity are built with the worker (an unknown backend raises from
    # #initialize, so the Supervisor skips the printer) and are instance variables rather than attributes: they're the
    # worker's own state, touched only by its thread once started.
    class Worker < ApplicationModel
      include Runnable

      DEFAULT_INTERVAL = 2.0
      ERROR_TEXT_LENGTH = 200

      attribute :printer
      # Seconds between ticks, from PRINTER_MONITOR_INTERVAL by default (see .default_interval)
      attribute :interval, :float, default: -> { default_interval }

      #: Connectivity
      attr_reader :connectivity

      # Seconds between ticks, from PRINTER_MONITOR_INTERVAL (defaults to 2)
      #: -> Float
      def self.default_interval
        interval = ENV.fetch('PRINTER_MONITOR_INTERVAL', DEFAULT_INTERVAL).to_f
        interval.positive? ? interval : DEFAULT_INTERVAL
      end

      #: (**untyped attributes) -> void
      def initialize(**attributes)
        super
        @reader = Reader.for(printer) #: Reader
        @webcam = WebcamTracker.new(printer:, reader: @reader) #: WebcamTracker
        @connectivity = Connectivity.new(printer:, interval:) #: Connectivity
        # New, so that the first tick always saves it (#changed? is true until it's saved)
        @status = Printer::Status.new(printer:) #: Printer::Status
        @specs_checked = false #: bool
        # The state family of the last status saved, nil until one is (see #save_status)
        @saved_family = nil #: Printer::StateFamily?
      end

      # Reloads the status from the printer, saves it if it changed and writes the heartbeat. Never raises.
      # @override
      #: -> void
      def tick
        # The heartbeat is written even when saving failed (e.g. the GraphQL trigger raised)
        error = capture_error do
          reload_status
          save_status if status.changed?
        end
        error = capture_error { Heartbeat.create! } || error
        error ? publish_failed(error) : connectivity.record_publish_success
      end

      delegate :delay, to: :connectivity

      private

      # The last status reloaded, saved when it changed
      #: Printer::Status
      attr_reader :status

      # Saves the status, then asks the global queue for a dispatch pass when the printer just turned Operational: it
      # may be ready for a job (PrintQueue::Readiness). The worker remembers the family it saved last: no Redis read.
      # The first status saved counts as a change, so a printer that is Operational when its monitor starts (a new
      # printer, a restart) is dispatched to too.
      #: -> void
      def save_status
        status.save!
        family = status.state_family
        previous_family = @saved_family
        @saved_family = family
        return unless family == Printer::StateFamily::Operational && previous_family != family

        PrintQueue::DispatchRequest.new.save if PrintQueue.enabled?
      end

      # Reloads the status from the printer, with the camera of the webcam tracker. When the printer can't be read, the
      # status is OFFLINE instead (see #unreachable).
      #: -> void
      def reload_status
        status.reload(reader: @reader)
        @webcam.refresh
        connectivity.record_success
        fill_specs_once
        status.camera = @webcam.camera
      rescue StandardError => e
        record_failure(e)
        unreachable(e)
      end

      # OFFLINE, with the error, without a job or temperatures, and seen when the printer last answered
      #: (StandardError error) -> void
      def unreachable(error)
        status.assign_attributes(
          state_family: Printer::StateFamily::Offline, state_text: Printer::Status::UNREACHABLE_STATE_TEXT,
          error_text: error_text(error), file_name: nil, progress: nil, print_time_left: nil, hotend: nil, bed: nil,
          camera: @webcam.camera, last_seen_at: connectivity.last_seen_at, updated_at: Time.current
        )
      end

      # Enqueues FillPrinterSpecsJob when no fill has read the printer's server yet (`specs_filled_at` is nil), e.g. it
      # was unreachable when it was added. Once per worker: the job sets the column, and a changed address (which
      # clears it) restarts the worker. Never raises: the poll succeeded.
      #: -> void
      def fill_specs_once
        return if @specs_checked

        @specs_checked = true
        # The worker's printer was loaded when it started: read the column again
        return if Printer.where(id: printer.id).pick(:specs_filled_at)

        FillPrinterSpecsJob.perform_later(printer.id)
        log(:info, 'Filling its blank specs in the background: it answered, and no fill has read its server yet')
      rescue StandardError => e
        log_exception('Failed to enqueue FillPrinterSpecsJob', e)
      end

      #: (StandardError error) -> void
      def record_failure(error)
        connectivity.record_failure
        @webcam.expire # Fetch the webcam settings again once reconnected
        log_failure(error) if connectivity.failures == 1
      end

      # Runs the block and returns the error it raised, if any
      #: { -> void } -> StandardError?
      def capture_error(&block)
        block.call
        nil
      rescue StandardError => e
        e
      end

      # Only the first failure of a streak is logged, so a Redis outage doesn't flood the logs
      #: (StandardError error) -> void
      def publish_failed(error)
        streak = connectivity.record_publish_failure
        log_exception('Failed to publish the printer status', error) if streak == 1
      end

      #: (StandardError error) -> String
      def error_text(error)
        return error.message if error.is_a?(Printer::Backend::UnreadableCredentials)
        return "Missing #{product_name} credentials" if error.is_a?(Printer::Backend::MissingCredentials)

        (error.message.presence || error.class.name.to_s).truncate(ERROR_TEXT_LENGTH)
      end

      # Only the first failure of a streak is logged, so unreachable printers don't flood the logs
      #: (StandardError error) -> void
      def log_failure(error)
        if error.is_a?(Printer::Backend::Error)
          log(:warn, "Unreachable: #{error_text(error)}")
        else
          log_exception("Unexpected error while polling #{product_name}", error)
        end
      end

      # "OctoPrint", "PrusaLink"
      #: -> String
      def product_name
        printer.api.product_name
      end
    end
  end
end
