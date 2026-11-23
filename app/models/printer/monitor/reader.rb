# typed: strict
# frozen_string_literal: true

class Printer
  module Monitor
    # Reads a printer's live state for Printer::Status#reload. Each backend has its own reader, as the monitor reads
    # more than the API adapters expose (temperatures, time left, ...) and in as few requests as possible.
    #
    #   reader = Printer::Monitor::Reader.for(printer)
    #   reader.status_attributes # => { state_family:, state_text:, hotend:, ... }
    #   Printer::Status.new(printer:).reload(reader:)
    #
    # A reader can keep state between reads (see PrusalinkReader): the Worker keeps its reader for the printer's life.
    # @interface
    module Reader
      extend ActiveSupport::Concern

      # The job and temperatures, as Printer::Status attributes: every attribute that Printer::Status#reload replaces
      # (state_family, state_text, error_text, file_name, progress, print_time_left, hotend, bed).
      # Raises Printer::Backend::Error (e.g. Unreachable) when the printer can't be read.
      # @abstract
      #: -> Hash[Symbol, untyped]
      def status_attributes = super

      # Raises Printer::Backend::Error when the webcam settings can't be read
      # @abstract
      #: -> Printer::Status::Camera
      def camera = super

      # The reader that the printer's adapter names (see Printer::Backend::ADAPTERS)
      #: (Printer printer) -> Reader
      def self.for(printer)
        Printer::Backend.adapter_class(printer.backend).reader_class.new(printer:)
      end
    end
  end
end
