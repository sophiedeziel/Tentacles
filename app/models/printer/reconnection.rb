# typed: true
# frozen_string_literal: true

class Printer
  # Closes the server's connection to a printer in ERROR, then opens it again (see Printer::Connection). Refused for
  # the backends that connect on their own (PrusaLink). See Printer::Command.
  #
  #   reconnection = Printer::Reconnection.new(printer:)
  #   reconnection.save          # => false when refused or when the printer fails
  #   reconnection.errors[:base] # => ['Prusa MK4 is no longer in error']
  class Reconnection < Command
    private

    def connection_command?
      true
    end

    def refusal(family)
      "#{printer.name} is no longer in error" unless family == StateFamily::Error
    end

    def send_command
      printer.api.reconnect
    end
  end
end
