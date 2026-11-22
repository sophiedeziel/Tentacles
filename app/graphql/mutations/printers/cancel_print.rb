# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saves a Printer::Cancellation
    class CancelPrint < PrinterAction
      description 'Cancels the print under way on a printer (allowed while PRINTING or PAUSED)'

      argument :expected_file_name, String, required: false,
                                            description: 'The file the user confirmed for: refuses when the ' \
                                                         'printer is printing another one'

      private

      def command_class = ::Printer::Cancellation
    end
  end
end
