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
    module Reader
      extend ActiveSupport::Concern
      extend T::Sig
      extend T::Helpers

      interface!

      # The job and temperatures, as Printer::Status attributes: every attribute that Printer::Status#reload replaces
      # (state_family, state_text, error_text, file_name, progress, print_time_left, hotend, bed).
      # Raises Printer::Backend::Error (e.g. Unreachable) when the printer can't be read.
      sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
      def status_attributes; end

      # Raises Printer::Backend::Error when the webcam settings can't be read
      sig { abstract.returns(Printer::Status::Camera) }
      def camera; end

      sig { params(printer: Printer).returns(Reader) }
      # The reader that the printer's adapter names (see Printer::Backend::ADAPTERS)
      def self.for(printer)
        Printer::Backend.adapter_class(printer.backend).reader_class.new(printer:)
      end
    end
  end
end
