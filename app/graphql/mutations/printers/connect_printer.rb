# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Connects OctoPrint to the printer (allowed while OFFLINE, once OctoPrint itself answers). The serial port and
    # baudrate are autodetected and OctoPrint uses its default printer profile.
    # Refused for the backends that connect on their own (PrusaLink).
    class ConnectPrinter < PrinterAction
      description 'Connects OctoPrint to an OFFLINE printer (autodetected port and baudrate, default profile)'

      private

      def connection_command?
        true
      end

      def refusal(printer, family)
        case family
        when PrinterStateFamily::Offline then nil
        when PrinterStateFamily::Connecting then "#{printer.name} is already connecting"
        when PrinterStateFamily::Error then "#{printer.name} is in error, reconnect it instead"
        else "#{printer.name} is already connected"
        end
      end

      def send_command(printer)
        printer.api.connect
      end
    end
  end
end
