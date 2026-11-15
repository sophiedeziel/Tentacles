# typed: true
# frozen_string_literal: true

module PrinterMonitor
  # Prefixes the monitor's log lines with the printer they are about
  module Logging
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { abstract.returns(Printer) }
    def printer; end

    private

    sig { params(message: String, error: StandardError).void }
    def log_exception(message, error)
      log(:error, "#{message}: #{error.class}: #{error.message}")
      Rails.logger.debug { error.backtrace&.first(10)&.join("\n") }
    end

    sig { params(level: Symbol, message: String).void }
    def log(level, message)
      Rails.logger.public_send(level, "[PrinterMonitor] #{printer.name} (##{printer.id}): #{message}")
    end
  end
end
