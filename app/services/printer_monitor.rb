# typed: strict
# frozen_string_literal: true

# Polls each printer's OctoPrint and publishes its live state as PrinterStatus snapshots (see Supervisor and Worker,
# run by bin/printer_monitor).
module PrinterMonitor
  class << self
    extend T::Sig

    # Stores the snapshot in Redis and notifies the printerStatusChanged subscribers
    sig { params(status: PrinterStatus, printer: Printer).void }
    def publish(status, printer)
      PrinterStatusStore.write(status)
      TentaclesSchema.subscriptions.trigger(:printer_status_changed, {}, printer)
    end

    # Runs one monitor tick for the printer in the current thread, e.g. right after a printer action, so that the new
    # state is pushed without waiting for the monitor's next tick.
    #
    # Returns the snapshot, or nil when OctoPrint or Redis couldn't be reached. Never raises: the monitor reports the
    # printer on its next tick anyway.
    #
    #   PrinterMonitor.refresh(printer) # => PrinterStatus or nil
    sig { params(printer: Printer).returns(T.nilable(PrinterStatus)) }
    def refresh(printer)
      InlineTick.new(printer).call
    end
  end
end
