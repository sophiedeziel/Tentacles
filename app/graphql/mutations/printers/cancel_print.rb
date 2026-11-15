# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    class CancelPrint < PrinterAction
      description 'Cancels the print under way on a printer (allowed while PRINTING or PAUSED)'

      argument :expected_file_name, String, required: false,
                                            description: 'The file the user confirmed for: refuses when the ' \
                                                         'printer is printing another one'

      CANCELLABLE = T.let([PrinterStateFamily::Printing, PrinterStateFamily::Paused].freeze,
                          T::Array[PrinterStateFamily])

      private

      def refusal(printer, family)
        "#{printer.name} is no longer printing" unless CANCELLABLE.include?(family)
      end

      def send_command(printer)
        printer.api.cancel
      end
    end
  end
end
