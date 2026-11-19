# typed: true
# frozen_string_literal: true

module PrinterMonitor
  # Polls one printer's API (OctoPrint, PrusaLink) in its own thread and publishes a PrinterStatus snapshot when
  # its state changes.
  #
  # Every tick reads the job and the temperatures through the printer's Reader. The snapshot is stored in Redis and
  # the GraphQL subscribers are notified only when it differs from the last one written.
  # Unreachable printers are reported as OFFLINE and polled less and less often (see Connectivity#delay).
  # The first time the printer answers, its blank specs are filled in the background unless a fill already read its
  # server (see #fill_specs_once).
  #
  #   worker = PrinterMonitor::Worker.new(printer).start
  #   worker.stop
  #   worker.join
  class Worker
    extend T::Sig
    include Runnable

    DEFAULT_INTERVAL = 2.0
    ERROR_TEXT_LENGTH = 200

    sig { override.returns(Printer) }
    attr_reader :printer

    sig { returns(Connectivity) }
    attr_reader :connectivity

    # Seconds between ticks, from PRINTER_MONITOR_INTERVAL (defaults to 2)
    sig { returns(Float) }
    def self.default_interval
      interval = ENV.fetch('PRINTER_MONITOR_INTERVAL', DEFAULT_INTERVAL).to_f
      interval.positive? ? interval : DEFAULT_INTERVAL
    end

    sig { params(printer: Printer, interval: Float).void }
    def initialize(printer, interval: self.class.default_interval)
      @printer = printer
      @reader = T.let(Reader.for(printer), Reader)
      @webcam = T.let(WebcamTracker.new(printer, @reader), WebcamTracker)
      @connectivity = T.let(Connectivity.new(printer, interval:), Connectivity)
      @previous = T.let(nil, T.nilable(PrinterStatus))
      @specs_checked = T.let(false, T::Boolean)
    end

    # Polls the printer once, publishes the snapshot if it changed and writes the heartbeat. Never raises.
    sig { override.void }
    def tick
      # The heartbeat is written even when publishing failed (e.g. the GraphQL trigger raised)
      error = capture_error { publish(poll) }
      error = capture_error { PrinterStatusStore.beat! } || error
      error ? publish_failed(error) : connectivity.record_publish_success
    end

    delegate :delay, to: :connectivity

    private

    sig { returns(PrinterStatus) }
    def poll
      attributes = @reader.status_attributes
      @webcam.refresh
      connectivity.record_success
      fill_specs_once
      build_status(attributes)
    rescue StandardError => e
      record_failure(e)
      build_status({ state_family: PrinterStateFamily::Offline, state_text: PrinterStatus::UNREACHABLE_STATE_TEXT,
                     error_text: error_text(e) })
    end

    # Enqueues FillPrinterSpecsJob when no fill has read the printer's server yet (`specs_filled_at` is nil), e.g. it
    # was unreachable when it was added. Once per worker: the job sets the column, and a changed address (which clears
    # it) restarts the worker. Never raises: the poll succeeded.
    sig { void }
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

    sig { params(status: PrinterStatus).void }
    def publish(status)
      return if status.same_as?(@previous)

      PrinterMonitor.publish(status, printer)
      @previous = status
    end

    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(PrinterStatus) }
    def build_status(attributes)
      base = { printer_id: printer.id, camera: @webcam.camera, last_seen_at: connectivity.last_seen_at,
               updated_at: Time.current }
      PrinterStatus.new(**T.unsafe(base.merge(attributes)))
    end

    sig { params(error: StandardError).void }
    def record_failure(error)
      connectivity.record_failure
      @webcam.expire # Fetch the webcam settings again once reconnected
      log_failure(error) if connectivity.failures == 1
    end

    # Runs the block and returns the error it raised, if any
    sig { params(block: T.proc.void).returns(T.nilable(StandardError)) }
    def capture_error(&block)
      block.call
      nil
    rescue StandardError => e
      e
    end

    # Only the first failure of a streak is logged, so a Redis outage doesn't flood the logs
    sig { params(error: StandardError).void }
    def publish_failed(error)
      streak = connectivity.record_publish_failure
      log_exception('Failed to publish the printer status', error) if streak == 1
    end

    sig { params(error: StandardError).returns(String) }
    def error_text(error)
      return error.message if error.is_a?(PrinterBackends::UnreadableCredentials)
      return "Missing #{product_name} credentials" if error.is_a?(PrinterBackends::MissingCredentials)

      (error.message.presence || error.class.name.to_s).truncate(ERROR_TEXT_LENGTH)
    end

    # Only the first failure of a streak is logged, so unreachable printers don't flood the logs
    sig { params(error: StandardError).void }
    def log_failure(error)
      if error.is_a?(PrinterBackends::Error)
        log(:warn, "Unreachable: #{error_text(error)}")
      else
        log_exception("Unexpected error while polling #{product_name}", error)
      end
    end

    # "OctoPrint", "PrusaLink"
    sig { returns(String) }
    def product_name
      printer.api.product_name
    end
  end
end
