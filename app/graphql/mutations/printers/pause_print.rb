# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saves a Printer::Pause
    class PausePrint < PrinterAction
      description 'Pauses the print under way on a printer (allowed while PRINTING)'

      argument :expected_file_name, String, required: false,
                                            description: 'The file the user confirmed for: refuses when the ' \
                                                         'printer is printing another one'

      private

      def command_class = ::Printer::Pause
    end
  end
end
