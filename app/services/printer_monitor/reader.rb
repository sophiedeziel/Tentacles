# typed: strict
# frozen_string_literal: true

module PrinterMonitor
  # Reads a printer's live state for the monitor. Each backend has its own reader, as the monitor reads more than
  # the API adapters expose (temperatures, time left, ...) and in as few requests as possible.
  #
  #   PrinterMonitor::Reader.for(printer).status_attributes # => { state_family:, state_text:, hotend:, ... }
  module Reader
    extend T::Sig
    extend T::Helpers

    interface!

    # The job and temperatures, as PrinterStatus attributes.
    # Raises PrinterBackends::Error (e.g. Unreachable) when the printer can't be read.
    sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
    def status_attributes; end

    # Raises PrinterBackends::Error when the webcam settings can't be read
    sig { abstract.returns(PrinterStatus::Camera) }
    def camera; end

    sig { params(printer: Printer).returns(Reader) }
    def self.for(printer)
      case printer.backend
      when 'octoprint' then OctoprintReader.new(printer)
      when 'prusalink' then PrusalinkReader.new(printer)
      else raise ArgumentError, "Unknown printer backend #{printer.backend.inspect}"
      end
    end
  end
end
