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
    # @abstract
    module Logging
      extend ActiveSupport::Concern

      # Implemented by the including model's `printer` attribute
      # @abstract
      #: -> Printer
      def printer = super

      private

      #: (String message, StandardError error) -> void
      def log_exception(message, error)
        log(:error, "#{message}: #{error.class}: #{error.message}")
        Rails.logger.debug { error.backtrace&.first(10)&.join("\n") }
      end

      #: (Symbol level, String message) -> void
      def log(level, message)
        Rails.logger.public_send(level, "[Printer::Monitor] #{printer.name} (##{printer.id}): #{message}")
      end
    end
  end
end
