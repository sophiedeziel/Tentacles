# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Closes OctoPrint's connection to a printer in error, then opens it again (see ConnectPrinter)
    # Refused for the backends that connect on their own (PrusaLink).
    class ReconnectPrinter < PrinterAction
      description 'Disconnects then reconnects OctoPrint to a printer in ERROR'

      private

      def connection_command?
        true
      end

      def refusal(printer, family)
        "#{printer.name} is no longer in error" unless family == PrinterStateFamily::Error
      end

      def send_command(printer)
        printer.api.reconnect
      end
    end
  end
end
