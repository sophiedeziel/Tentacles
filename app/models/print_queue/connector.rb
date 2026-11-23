# typed: true
# frozen_string_literal: true

module PrintQueue
  # How the global queue talks to the printers about a copy (a Printer::Job of an entry): the "in" side of the
  # connector. PrintQueue.connector returns the one in use: PrintQueue::Connector::Spooler (through the spooler and
  # the printer's API), or PrintQueue::Connector::Fake (the scenario specs, the console).
  #
  #   PrintQueue.connector.start(printer_job)  # the dispatcher, once the copy is committed
  #   PrintQueue.connector.cancel(printer_job) # PrintQueue::CopyCancellation, for a copy under way
  #
  # Its out side, what happens to the copy on the printer, is the queue's events (PrintQueue::PrintStart,
  # PrintQueue::PrintEnd, ...), recorded by the spool and the monitor, or fired by the fake.
  #
  # A connector has nothing to save (#save raises NotImplementedError): the queue's commands go through it.
  # @abstract
  class Connector < ApplicationModel
    self.abstract_class = true

    # Starts the copy on its printer. Best effort: the spooler's sweep starts a copy left enqueued.
    # @abstract
    #: (Printer::Job printer_job) -> void
    def start(printer_job) = super

    # Pauses the copy's print. The command comes back without errors when it was accepted, with its `errors` when it
    # was refused or failed.
    # @abstract
    #: (Printer::Job printer_job) -> Printer::Command
    def pause(printer_job) = super

    # Resumes the copy's paused print. Same result as #pause.
    # @abstract
    #: (Printer::Job printer_job) -> Printer::Command
    def resume(printer_job) = super

    # Cancels the copy's print. Same result as #pause.
    # @abstract
    #: (Printer::Job printer_job) -> Printer::Command
    def cancel(printer_job) = super
  end
end
