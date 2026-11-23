# typed: true
# frozen_string_literal: true

module PrintQueue
  # A printer event: the printer went offline (Offline, Connecting or Error, seen by its monitor,
  # Printer::Monitor::Worker). Nothing is stored: its queue is pushed, the queue's entries that wait for it now wait
  # for a reconnect (PrintQueue::Fit). See PrintQueue::Event.
  #
  #   PrintQueue::PrinterOffline.new(printer:).save
  class PrinterOffline < Event
    attribute :printer

    validates :printer, presence: true

    private

    #: -> void
    def persist
      PrintQueue.push_changed([printer])
    end
  end
end
