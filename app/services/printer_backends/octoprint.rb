# typed: true
# frozen_string_literal: true

module PrinterBackends
  # OctoPrint, through the octoprint gem.
  #
  # Every request runs in `client.use`, which sets the printer's own client for the current thread only: the gem's
  # global configuration is never touched. The gem's errors are translated into PrinterBackends errors (see
  # .translate_errors). Answers that aren't OctoPrint's (an HTML page: JSON::ParserError, no `error` key: KeyError)
  # and malformed URLs (URI::InvalidURIError) are raised as they are.
  #
  # Inside this class, `Octoprint` is the adapter itself: the gem is `::Octoprint`.
  class Octoprint < Base # rubocop:disable Metrics/ClassLength -- one short method per operation of the interface
    # Seconds to wait for OctoPrint when uploading G-code files
    UPLOAD_OPEN_TIMEOUT = 5
    UPLOAD_TIMEOUT = 120

    class << self
      extend T::Sig

      # Runs the block, raising the gem's errors as PrinterBackends errors with the same message
      sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
      def translate_errors(&block)
        block.call
      rescue ::Octoprint::Exceptions::MissingCredentialsError
        raise MissingCredentials, 'Missing OctoPrint credentials'
      rescue ::Octoprint::Exceptions::ConnectionError => e # Includes TimeoutError
        raise Unreachable, e.message
      rescue ::Octoprint::Exceptions::AuthenticationError => e
        raise Unauthorized, e.message
      rescue ::Octoprint::Exceptions::Error => e
        raise Error, e.message
      end

      # Autodetected serial port and baudrate, with OctoPrint's default printer profile.
      # A new hash on every call: Octoprint::Connection.connect adds the command to the hash it's given.
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def connection_params
        { port: 'AUTO', baudrate: 0 }
      end

      # OctoPrint often returns the stream URL relative to its own host ("/webcam/?action=stream"). Returns nil
      # when the URL is blank, invalid or not HTTP(S). Never hands the OctoPrint credentials (user:password@) to
      # the browser.
      sig { params(base: T.nilable(String), url: T.nilable(String)).returns(T.nilable(String)) }
      def stream_url(base, url)
        return nil if url.blank?

        base = base.to_s
        base = "#{base}/" unless base.end_with?('/')
        resolved = URI.join(base, url)
        return nil unless resolved.is_a?(URI::HTTP) # URI::HTTPS is a URI::HTTP

        resolved.user = nil
        resolved.to_s
      rescue URI::Error
        nil
      end
    end

    sig { override.returns(T.nilable(T::Hash[Symbol, T.untyped])) }
    def current_job
      job = use { ::Octoprint::Job.get }
      name = job.information&.file&.[](:name)
      completion = job.progress&.completion
      return nil if name.nil? || completion.nil?

      { name:, progress: completion.to_f }
    end

    sig { override.returns(T.nilable(String)) }
    def job_status
      use { ::Octoprint::Job.get }.state
    end

    sig { override.returns(PrinterStateFamily) }
    def state_family
      PrinterStateFamily.for(job_status)
    end

    sig { override.returns(T::Hash[Symbol, T.untyped]) }
    def print_progress
      job = use { ::Octoprint::Job.get }
      { state_family: PrinterStateFamily.for(job.state), progress: job.progress&.completion&.to_f }
    end

    sig { override.returns(T::Hash[Symbol, T.untyped]) }
    def live_job
      job = use { ::Octoprint::Job.get }
      { state_family: PrinterStateFamily.for(job.state), file_name: job.information&.file&.[](:name) }
    end

    sig { override.returns(T.nilable(String)) }
    def version
      use { ::Octoprint::ServerVersion.get }.text
    end

    # The name of OctoPrint's default printer profile
    sig { override.returns(T::Hash[Symbol, T.nilable(String)]) }
    def identify
      connection = use { ::Octoprint::Connection.get }
      profile = connection.options&.printer_profiles&.find { |p| p[:id] == '_default' }
      { name: profile&.dig(:name), version: }
    end

    sig { override.returns(T.nilable(String)) }
    def webcam_url
      webcam = use { ::Octoprint::Settings.webcam }
      return nil unless webcam.enabled

      self.class.stream_url(printer.uri, webcam.stream_url)
    end

    sig { override.void }
    def pause
      use { ::Octoprint::Job.pause }
    end

    sig { override.void }
    def resume
      use { ::Octoprint::Job.resume }
    end

    sig { override.void }
    def cancel
      use { ::Octoprint::Job.cancel }
    end

    sig { override.void }
    def connect
      use { ::Octoprint::Connection.connect(self.class.connection_params) }
    end

    sig { override.void }
    def reconnect
      use do
        ::Octoprint::Connection.disconnect
        ::Octoprint::Connection.connect(self.class.connection_params)
      end
    end

    # With its own client: large G-code files take much longer to upload than the API client's 3 seconds read timeout
    sig { override.params(path: String, print: T::Boolean).void }
    def upload(path, print: false)
      options = { path: nil, select: print || nil, print: print || nil, userdata: nil }
      self.class.translate_errors { upload_client.use { ::Octoprint::Files.upload(path, options:) } }
    end

    # The printer's OctoPrint client, for the OctoPrint-specific PrinterMonitor::OctoprintReader.
    # Raises Octoprint::Exceptions::MissingCredentialsError when the URI or the API key is blank.
    sig { returns(::Octoprint::Client) }
    def client
      @client ||= T.let(
        ::Octoprint::Client.new(host: printer.uri.presence, api_key: printer.secret.presence),
        T.nilable(::Octoprint::Client)
      )
    end

    private

    # rubocop:disable Naming/BlockForwarding, Style/ArgumentsForwarding -- Sorbet sigs need a named block
    sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
    def use(&block)
      self.class.translate_errors { client.use(&block) }
    end
    # rubocop:enable Naming/BlockForwarding, Style/ArgumentsForwarding

    # Raises Octoprint::Exceptions::MissingCredentialsError when the URI or the API key is blank
    sig { returns(::Octoprint::Client) }
    def upload_client
      @upload_client ||= T.let(
        ::Octoprint::Client.new(host: printer.uri.presence, api_key: printer.secret.presence,
                                open_timeout: UPLOAD_OPEN_TIMEOUT, timeout: UPLOAD_TIMEOUT),
        T.nilable(::Octoprint::Client)
      )
    end
  end
end
