# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Closes OctoPrint's connection to a printer in error, then opens it again (see ConnectPrinter)
    class ReconnectPrinter < PrinterAction
      description 'Disconnects then reconnects OctoPrint to a printer in ERROR'

      private

      def refusal(printer, family)
        "#{printer.name} is no longer in error" unless family == PrinterStateFamily::Error
      end

      def send_command(_printer)
        Octoprint::Connection.disconnect
        Octoprint::Connection.connect(ConnectPrinter.connection_params)
      end
    end
  end
end
