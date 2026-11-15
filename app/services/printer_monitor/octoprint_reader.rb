# typed: true
# frozen_string_literal: true

module PrinterMonitor
  # Reads a printer's state from its OctoPrint with the printer's own client (see PrinterBackends::Octoprint#client).
  #
  # Every call runs in `client.use`, which sets the client for the current thread only. The OctoPrint errors that
  # escape #status_attributes and #camera are raised as PrinterBackends errors.
  class OctoprintReader
    extend T::Sig
    include Logging
    include Reader

    Temperatures = T.type_alias { [T.nilable(PrinterStatus::Temperature), T.nilable(PrinterStatus::Temperature)] }
    # Longest text kept from OctoPrint (state, error, file name)
    MAX_TEXT_LENGTH = 255

    sig { override.returns(Printer) }
    attr_reader :printer

    sig { params(printer: Printer).void }
    def initialize(printer)
      @printer = printer
      @temperatures_failing = T.let(false, T::Boolean)
    end

    # The job and temperatures, as PrinterStatus attributes.
    # Raises PrinterBackends::Error (e.g. Unreachable) when OctoPrint can't be reached.
    sig { override.returns(T::Hash[Symbol, T.untyped]) }
    def status_attributes
      PrinterBackends::Octoprint.translate_errors do
        job = api { Octoprint::Job.get }
        state_family = PrinterStateFamily.for(job.state)
        hotend, bed = temperatures(state_family)

        job_attributes(job).merge(state_family:, hotend:, bed:)
      end
    end

    # Raises PrinterBackends::Error when the settings can't be read
    sig { override.returns(PrinterStatus::Camera) }
    def camera
      webcam = PrinterBackends::Octoprint.translate_errors { api { Octoprint::Settings.webcam } }
      PrinterStatus::Camera.new(enabled: webcam.enabled,
                                stream_url: PrinterBackends::Octoprint.stream_url(printer.uri, webcam.stream_url))
    end

    private

    sig { params(job: Octoprint::Job).returns(T::Hash[Symbol, T.untyped]) }
    def job_attributes(job)
      progress = job.progress
      {
        state_text: text(job.state) || PrinterStatus::UNKNOWN_STATE_TEXT,
        error_text: text(job.error),
        file_name: text(job.information&.file&.[](:name)),
        progress: progress&.completion&.to_f,
        print_time_left: progress&.print_time_left&.round
      }
    end

    # Hotend (tool 0) and bed temperatures. Only available when OctoPrint is connected to the printer.
    sig { params(state_family: PrinterStateFamily).returns(Temperatures) }
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

    sig { returns(Temperatures) }
    def read_temperatures
      temperature = api { Octoprint::Printer.get(exclude: %i[sd state]) }.temperature
      @temperatures_failing = false
      [to_temperature(temperature&.tool(0)), to_temperature(temperature&.bed)]
    end

    # Only the first failure of a streak is logged, so a broken printer doesn't flood the logs
    sig { params(error: StandardError).void }
    def temperatures_failed(error)
      log_exception('Failed to read the temperatures', error) unless @temperatures_failing
      @temperatures_failing = true
    end

    sig { params(data: T.nilable(Octoprint::Printer::TemperatureData)).returns(T.nilable(PrinterStatus::Temperature)) }
    def to_temperature(data)
      return nil if data.nil?

      PrinterStatus::Temperature.new(actual: data.actual&.to_f, target: data.target&.to_f, unit: TemperatureUnit::Celsius)
    end

    sig { params(value: T.untyped).returns(T.nilable(String)) }
    def text(value)
      value.to_s.presence&.truncate(MAX_TEXT_LENGTH)
    end

    # rubocop:disable Naming/BlockForwarding, Style/ArgumentsForwarding -- Sorbet sigs need a named block
    sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
    def api(&block)
      client.use(&block)
    end
    # rubocop:enable Naming/BlockForwarding, Style/ArgumentsForwarding

    # Raises Octoprint::Exceptions::MissingCredentialsError when the URI or the API key is blank
    sig { returns(Octoprint::Client) }
    def client
      T.cast(printer.api, PrinterBackends::Octoprint).client
    end
  end
end
