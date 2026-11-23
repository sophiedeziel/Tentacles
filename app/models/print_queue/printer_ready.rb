# typed: true
# frozen_string_literal: true

module PrintQueue
  # A printer event: the printer turned Operational (its monitor, Printer::Monitor::Worker), so it may be ready for a
  # copy. Asks for a dispatch pass (PrintQueue::DispatchRequest). See PrintQueue::Event.
  #
  #   PrintQueue::PrinterReady.new(printer:).save
  #
  # It never ends the copy the printer's row says is active, even though a ready printer prints nothing: the copy's
  # spool owns it, and ends it when it sees the print is over (or adopts it after a restart, Spooler::Spool). The
  # printer stays busy for the queue (PrintQueue::Readiness) until then.
  class PrinterReady < Event
    attribute :printer

    validates :printer, presence: true

    private

    #: -> void
    def persist
      PrintQueue::DispatchRequest.new.save
    end
  end
end
