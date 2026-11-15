# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Connects OctoPrint to the printer (allowed while OFFLINE, once OctoPrint itself answers). The serial port and
    # baudrate are autodetected and OctoPrint uses its default printer profile.
    class ConnectPrinter < PrinterAction
      description 'Connects OctoPrint to an OFFLINE printer (autodetected port and baudrate, default profile)'

      # A new hash on every call: Octoprint::Connection.connect adds the command to the hash it's given
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def self.connection_params
        { port: 'AUTO', baudrate: 0 }
      end

      private

      def refusal(printer, family)
        case family
        when PrinterStateFamily::Offline then nil
        when PrinterStateFamily::Connecting then "#{printer.name} is already connecting"
        when PrinterStateFamily::Error then "#{printer.name} is in error, reconnect it instead"
        else "#{printer.name} is already connected"
        end
      end

      def send_command(_printer)
        Octoprint::Connection.connect(self.class.connection_params)
      end
    end
  end
end
