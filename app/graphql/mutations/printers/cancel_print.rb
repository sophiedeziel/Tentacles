# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    class CancelPrint < PrinterAction
      description 'Cancels the print under way on a printer (allowed while PRINTING or PAUSED)'

      CANCELLABLE = T.let([PrinterStateFamily::Printing, PrinterStateFamily::Paused].freeze,
                          T::Array[PrinterStateFamily])

      private

      def refusal(printer, family)
        "#{printer.name} is no longer printing" unless CANCELLABLE.include?(family)
      end

      def send_command(_printer)
        Octoprint::Job.cancel
      end
    end
  end
end
