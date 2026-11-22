# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saves a Printer::Connection: connects OctoPrint to an OFFLINE printer. Refused for the backends that connect on
    # their own (PrusaLink).
    class ConnectPrinter < PrinterAction
      description "Connects the printer's server to an OFFLINE printer (OctoPrint: autodetected port and baudrate, " \
                  'default profile). Refused for the backends that connect on their own (PrusaLink)'

      private

      def command_class = ::Printer::Connection
    end
  end
end
