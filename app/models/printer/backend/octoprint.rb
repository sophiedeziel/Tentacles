# typed: true
# frozen_string_literal: true

class Printer
  class Backend
    # OctoPrint, through the octoprint gem.
    #
    #   adapter = Printer::Backend::Octoprint.new(printer:) # or printer.api, memoized
    #   adapter.live_job # => { state_family: Printer::StateFamily::Printing, file_name: 'cube.gcode' }
    #   adapter.pause
    #
    # Every request runs in `client.use`, which sets the printer's own client for the current thread only: the gem's
    # global configuration is never touched. The gem's errors are translated into Printer::Backend errors (see
    # .translate_errors). Answers that aren't OctoPrint's (an HTML page: JSON::ParserError, no `error` key: KeyError)
    # and malformed URLs (URI::InvalidURIError) are raised as they are.
    #
    # Inside this class, `Octoprint` is the adapter itself: the gem is `::Octoprint`.
    class Octoprint < Backend # rubocop:disable Metrics/ClassLength -- one short method per operation of the interface
      # Seconds to wait for OctoPrint when uploading G-code files
      UPLOAD_OPEN_TIMEOUT = 5
      UPLOAD_TIMEOUT = 120

      class << self
        extend T::Sig

        # Runs the block, raising the gem's errors as Printer::Backend errors with the same message
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

        # The specs columns of a printer profile
        sig { params(profile: ::Octoprint::PrinterProfiles::PrinterProfile).returns(T::Hash[Symbol, T.untyped]) }
        def profile_specs(profile)
          extruder = profile.extruder
          { name: profile.name.presence, model: profile.model.presence, heated_bed: profile.heated_bed,
            heated_chamber: profile.heated_chamber, extruders: extruder[:count]&.to_i,
            nozzle_diameter: extruder[:nozzleDiameter]&.to_f, **build_volume(profile.volume) }
        end

        # The build volume columns (mm) of a printer profile's `volume`: the width is the diameter of a circular bed
        #
        #   build_volume({ formFactor: 'circular', width: 180, depth: 180, height: 300 })
        #   # => { bed_shape: 'circular', build_diameter: 180.0, build_volume_z: 300.0 }
        sig { params(volume: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
        def build_volume(volume)
          width, depth, height = volume.values_at(:width, :depth, :height).map { |size| size&.to_f }
          shape = volume[:formFactor]
          return { bed_shape: 'circular', build_diameter: width, build_volume_z: height } if shape == 'circular'

          { bed_shape: ('rectangular' if shape == 'rectangular'),
            build_volume_x: width, build_volume_y: depth, build_volume_z: height }
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

      sig { override.returns(String) }
      def product_name
        'OctoPrint'
      end

      sig { override.returns(String) }
      def secret_name
        'API key'
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

      sig { override.returns(Printer::StateFamily) }
      def state_family
        Printer::StateFamily.for(job_status)
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def print_progress
        job = use { ::Octoprint::Job.get }
        { state_family: Printer::StateFamily.for(job.state), progress: job.progress&.completion&.to_f }
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def live_job
        job = use { ::Octoprint::Job.get }
        { state_family: Printer::StateFamily.for(job.state), file_name: job.information&.file&.[](:name) }
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

      # From the current printer profile (else the default one) and the webcam settings. OctoPrint doesn't know the
      # firmware. A circular (delta) bed has its diameter in the profile's width.
      sig { override.returns(ReportedSpecs) }
      def reported_specs
        webcam = use { ::Octoprint::Settings.webcam }.enabled
        profile = current_profile
        ReportedSpecs.new(webcam:, **(profile ? self.class.profile_specs(profile) : {}))
      end

      sig { override.returns(T.nilable(String)) }
      def webcam_url
        webcam = use { ::Octoprint::Settings.webcam }
        return nil unless webcam.enabled

        self.class.stream_url(printer.uri, webcam.stream_url)
      end

      # OctoPrint has a single job, without an id: the job commands ignore job_id
      sig { override.params(job_id: T.nilable(Integer)).void }
      def pause(job_id: nil) # rubocop:disable Lint/UnusedMethodArgument
        use { ::Octoprint::Job.pause }
      end

      sig { override.params(job_id: T.nilable(Integer)).void }
      def resume(job_id: nil) # rubocop:disable Lint/UnusedMethodArgument
        use { ::Octoprint::Job.resume }
      end

      sig { override.params(job_id: T.nilable(Integer)).void }
      def cancel(job_id: nil) # rubocop:disable Lint/UnusedMethodArgument
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

      # The printer's OctoPrint client, for the OctoPrint-specific Printer::Monitor::OctoprintReader.
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

      # The printer profile in use: the current one, else the default one. nil when OctoPrint has neither.
      sig { returns(T.nilable(::Octoprint::PrinterProfiles::PrinterProfile)) }
      def current_profile
        profiles = use { ::Octoprint::PrinterProfiles.list }.profiles.values
        profiles.find(&:current) || profiles.find(&:default)
      end

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
end
