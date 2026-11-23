# typed: true
# frozen_string_literal: true

class Printer
  module Monitor
    # Reads a printer's state from its OctoPrint with the printer's own client (see Printer::Backend::Octoprint#client).
    #
    #   Printer::Monitor::OctoprintReader.new(printer:).status_attributes # => { state_family:, state_text:, ... }
    #
    # Every call runs in `client.use`, which sets the client for the current thread only. The OctoPrint errors that
    # escape #status_attributes and #camera are raised as Printer::Backend errors.
    class OctoprintReader < ApplicationModel
      include Logging
      include Reader

      Temperatures = T.type_alias { [T.nilable(Printer::Status::Temperature), T.nilable(Printer::Status::Temperature)] }
      # Longest text kept from OctoPrint (state, error, file name)
      MAX_TEXT_LENGTH = 255

      attribute :printer

      #: (**untyped attributes) -> void
      def initialize(**attributes)
        super
        # Whether the temperatures failed on the last read: the reader's own state (see #temperatures_failed)
        @temperatures_failing = false #: bool
      end

      # The job and temperatures, as Printer::Status attributes.
      # Raises Printer::Backend::Error (e.g. Unreachable) when OctoPrint can't be reached.
      # @override
      #: -> Hash[Symbol, untyped]
      def status_attributes
        Printer::Backend::Octoprint.translate_errors do
          job = api { Octoprint::Job.get }
          state_family = Printer::StateFamily.for(job.state)
          hotend, bed = temperatures(state_family)

          job_attributes(job).merge(state_family:, hotend:, bed:)
        end
      end

      # Raises Printer::Backend::Error when the settings can't be read
      # @override
      #: -> Printer::Status::Camera
      def camera
        webcam = Printer::Backend::Octoprint.translate_errors { api { Octoprint::Settings.webcam } }
        Printer::Status::Camera.new(enabled: webcam.enabled,
                                    stream_url: Printer::Backend::Octoprint.stream_url(printer.uri, webcam.stream_url))
      end

      private

      #: (Octoprint::Job job) -> Hash[Symbol, untyped]
      def job_attributes(job)
        progress = job.progress
        {
          state_text: text(job.state) || Printer::Status::UNKNOWN_STATE_TEXT,
          error_text: text(job.error),
          file_name: text(job.information&.file&.[](:name)),
          progress: progress&.completion&.to_f,
          print_time_left: progress&.print_time_left&.round
        }
      end

      # Hotend (tool 0) and bed temperatures. Only available when OctoPrint is connected to the printer.
      #: (Printer::StateFamily state_family) -> Temperatures
      def temperatures(state_family)
        return [nil, nil] unless state_family.connected?

        read_temperatures
      rescue Octoprint::Exceptions::ConnectionError
        raise
      rescue Octoprint::Exceptions::ConflictError
        [nil, nil] # OctoPrint disconnected from the printer in the meantime
      # A server that isn't OctoPrint can answer with HTML (JSON::ParserError) or without an `error` key (KeyError)
      rescue Octoprint::Exceptions::Error, JSON::ParserError, KeyError => e
        temperatures_failed(e)
        [nil, nil]
      end

      #: -> Temperatures
      def read_temperatures
        temperature = api { Octoprint::Printer.get(exclude: %i[sd state]) }.temperature
        @temperatures_failing = false
        [to_temperature(temperature&.tool(0)), to_temperature(temperature&.bed)]
      end

      # Only the first failure of a streak is logged, so a broken printer doesn't flood the logs
      #: (StandardError error) -> void
      def temperatures_failed(error)
        log_exception('Failed to read the temperatures', error) unless @temperatures_failing
        @temperatures_failing = true
      end

      #: (
      #|   Octoprint::Printer::TemperatureData? data
      #| ) -> Printer::Status::Temperature?
      def to_temperature(data)
        return nil if data.nil?

        Printer::Status::Temperature.new(actual: data.actual&.to_f, target: data.target&.to_f,
                                         unit: TemperatureUnit::Celsius)
      end

      #: (untyped value) -> String?
      def text(value)
        value.to_s.presence&.truncate(MAX_TEXT_LENGTH)
      end

      # rubocop:disable Naming/BlockForwarding, Style/ArgumentsForwarding -- Sorbet sigs need a named block
      #: [T] { -> T } -> T
      def api(&block)
        client.use(&block)
      end
      # rubocop:enable Naming/BlockForwarding, Style/ArgumentsForwarding

      # Raises Octoprint::Exceptions::MissingCredentialsError when the URI or the API key is blank
      #: -> Octoprint::Client
      def client
        T.cast(printer.api, Printer::Backend::Octoprint).client
      end
    end
  end
end
