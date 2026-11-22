# typed: true
# frozen_string_literal: true

class Printer
  # Connects the printer's server to the printer (allowed while OFFLINE, once the server itself answers). OctoPrint
  # autodetects the serial port and baudrate and uses its default printer profile. Refused for the backends that
  # connect on their own (PrusaLink). See Printer::Command.
  #
  #   connection = Printer::Connection.new(printer:)
  #   connection.save          # => false when refused or when the printer fails
  #   connection.errors[:base] # => ['Prusa MK4 is in error, reconnect it instead'] (see Printer::Reconnection)
  class Connection < Command
    private

    def connection_command?
      true
    end

    def refusal(family)
      case family
      when StateFamily::Offline then nil
      when StateFamily::Connecting then "#{printer.name} is already connecting"
      when StateFamily::Error then "#{printer.name} is in error, reconnect it instead"
      else "#{printer.name} is already connected"
      end
    end

    def persist
      printer.api.connect
    end
  end
end
