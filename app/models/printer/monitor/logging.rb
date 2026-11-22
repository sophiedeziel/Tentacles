# typed: true
# frozen_string_literal: true

class Printer
  module Monitor
    # Prefixes the monitor's log lines with the printer they are about. For the monitor's models with a `printer`
    # attribute:
    #
    #   class Printer::Monitor::WebcamTracker < ApplicationModel
    #     include Printer::Monitor::Logging
    #     attribute :printer
    #   end
    #
    #   log(:warn, 'Unreachable') # => "[Printer::Monitor] Prusa MK4 (#3): Unreachable"
    module Logging
      extend ActiveSupport::Concern
      extend T::Sig
      extend T::Helpers

      abstract!

      # Implemented by the including model's `printer` attribute
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
        Rails.logger.public_send(level, "[Printer::Monitor] #{printer.name} (##{printer.id}): #{message}")
      end
    end
  end
end
