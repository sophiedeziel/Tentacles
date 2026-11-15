# typed: strict
# frozen_string_literal: true

module PrinterMonitor
  # One monitor tick for one printer, outside of the monitor process (see PrinterMonitor.refresh).
  #
  # Reads the job and temperatures with the monitor's reader (see Reader.for) and publishes the snapshot like a
  # Worker does (only when it changed). The webcam settings aren't read again: the camera of the last snapshot is
  # kept.
  class InlineTick
    extend T::Sig
    include Logging

    sig { override.returns(Printer) }
    attr_reader :printer

    sig { params(printer: Printer).void }
    def initialize(printer)
      @printer = printer
    end

    # Returns the snapshot, or nil when OctoPrint or Redis couldn't be reached (logged, never raised)
    sig { returns(T.nilable(PrinterStatus)) }
    def call
      previous = PrinterStatusStore.read(printer.id)
      status = build_status(Reader.for(printer).status_attributes, previous)
      PrinterMonitor.publish(status, printer) unless status.same_as?(previous)
      status
    rescue StandardError => e
      log(:warn, "Inline refresh failed: #{e.class}: #{e.message}")
      nil
    end

    private

    sig { params(attributes: T::Hash[Symbol, T.untyped], previous: T.nilable(PrinterStatus)).returns(PrinterStatus) }
    def build_status(attributes, previous)
      now = Time.current
      base = { printer_id: printer.id, camera: previous&.camera || PrinterStatus::Camera.new, last_seen_at: now,
               updated_at: now }
      PrinterStatus.new(**T.unsafe(base.merge(attributes)))
    end
  end
end
