# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    class PausePrint < PrinterAction
      description 'Pauses the print under way on a printer (allowed while PRINTING)'

      private

      def refusal(printer, family)
        "#{printer.name} is no longer printing" unless family == PrinterStateFamily::Printing
      end

      def send_command(_printer)
        Octoprint::Job.pause
      end
    end
  end
end
