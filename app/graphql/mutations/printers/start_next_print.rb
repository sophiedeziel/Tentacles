# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saves a Printer::NextPrintStart: asks the spooler to start the next job of a printer's queue, checked against
    # the LIVE state read from the printer (Printer.canStartNext uses the monitor's last snapshot instead).
    class StartNextPrint < PrinterAction
      description 'Mutation to start the next print in the queue for a printer'

      argument :expected_job_id, ID, required: false,
                                     description: 'The next job the user confirmed for: refuses when the queue ' \
                                                  'has another job first'

      private

      def command_class = ::Printer::NextPrintStart
    end
  end
end
