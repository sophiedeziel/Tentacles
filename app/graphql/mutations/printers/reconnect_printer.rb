# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saves a Printer::Reconnection: closes OctoPrint's connection to a printer in error, then opens it again.
    # Refused for the backends that connect on their own (PrusaLink).
    class ReconnectPrinter < PrinterAction
      description "Disconnects then reconnects the printer's server to a printer in ERROR. Refused for the backends " \
                  'that connect on their own (PrusaLink)'

      private

      def command_class = ::Printer::Reconnection
    end
  end
end
