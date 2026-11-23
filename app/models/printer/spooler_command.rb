# typed: strict
# frozen_string_literal: true

class Printer
  # The commands the app publishes on the `printers` Redis channel (Printer#notify_spooler) and the spooler
  # (lib/spooler.rb) runs. The serialized values are the wire format: `{ "command": "start_print", "printer_id": 1 }`.
  #
  #   printer.notify_spooler(Printer::SpoolerCommand::StartPrint)
  #   Printer::SpoolerCommand.deserialize('start_print') # => Printer::SpoolerCommand::StartPrint
  class SpoolerCommand < T::Enum
    enums do
      # A printer was added: the spooler gives it a spool (Printer::Addition)
      AddPrinter = new('add_printer')
      # A printer was removed: the spooler drops its spool, without sending anything to the printer (Printer::Removal)
      RemovePrinter = new('remove_printer')
      # The queue has a job to start (Printer::NextPrintStart, enqueueFiles)
      StartPrint = new('start_print')
      # Stops the printer's spool. Nothing in the app sends it.
      StopPrint = new('stop_print')
      # Resumes the printer's spool. Nothing in the app sends it.
      Resume = new('resume')
      # The global queue changed: the spooler runs a dispatch pass (PrintQueue::DispatchRequest). For the whole queue:
      # `{ "command": "dispatch" }`, without a printer_id
      Dispatch = new('dispatch')
    end
  end
end
