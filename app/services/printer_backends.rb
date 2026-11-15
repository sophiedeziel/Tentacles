# typed: strict
# frozen_string_literal: true

# The printer APIs Tentacles talks to, one adapter per `printers.backend` (see Base for the interface).
#
#   PrinterBackends.for(printer).state_family # => PrinterStateFamily::Operational
#
# Use Printer#api rather than calling this directly: it memoizes the adapter until the credentials change.
module PrinterBackends
  # Base of the errors the adapters raise. Translated from the client gems' errors, with the same message.
  class Error < StandardError; end
  # The printer can't be reached (connection refused, DNS failure, timeout, ...)
  class Unreachable < Error; end
  # The printer rejected the credentials
  class Unauthorized < Error; end
  # The printer has no URI or no secret
  class MissingCredentials < Error; end

  # The stored secret can't be decrypted (e.g. SECRET_KEY_BASE changed): the credentials must be entered again
  class UnreadableCredentials < MissingCredentials
    MESSAGE = "Stored credentials can't be read, re-enter them"
  end

  class << self
    extend T::Sig

    sig { params(printer: Printer).returns(Base) }
    def for(printer)
      case printer.backend
      when 'octoprint' then Octoprint.new(printer)
      else raise ArgumentError, "Unknown printer backend #{printer.backend.inspect}"
      end
    end
  end
end
