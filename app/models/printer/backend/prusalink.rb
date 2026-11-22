# typed: true
# frozen_string_literal: true

class Printer
  class Backend
    # PrusaLink (Prusa MK4, XL, MINI, ... without OctoPrint), through the prusalink gem.
    #
    #   adapter = Printer::Backend::Prusalink.new(printer:) # or printer.api, memoized
    #   adapter.live_job # => { state_family: Printer::StateFamily::Printing, file_name: 'cube.bgcode', job_id: 7 }
    #   adapter.pause(job_id: 7)
    #
    # Every request runs in `client.use`, which sets the printer's own client for the current thread only: the gem's
    # global configuration is never touched. The gem's errors are translated into Printer::Backend errors (see
    # .translate_errors). A malformed URL (URI::InvalidURIError) is raised as it is.
    #
    # PrusaLink connects to the printer by itself: #connect and #reconnect are refused.
    #
    # Inside this class, `Prusalink` is the adapter itself: the gem is `::Prusalink`.
    class Prusalink < Backend # rubocop:disable Metrics/ClassLength -- one short method per operation of the interface
      # Seconds to wait for PrusaLink
      OPEN_TIMEOUT = 2
      TIMEOUT = 5
      # Seconds to wait for PrusaLink when uploading G-code files
      UPLOAD_OPEN_TIMEOUT = 5
      UPLOAD_TIMEOUT = 120

      CONNECTS_ON_ITS_OWN = 'PrusaLink printers connect on their own'

      class << self
        extend T::Sig

        sig { override.returns(Printer::Backend::ReaderClass) }
        def reader_class
          Printer::Monitor::PrusalinkReader
        end

        # Runs the block, raising the gem's errors as Printer::Backend errors with the same message
        sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
        def translate_errors(&block)
          block.call
        rescue ::Prusalink::Exceptions::MissingCredentialsError
          raise MissingCredentials, 'Missing PrusaLink credentials'
        rescue ::Prusalink::Exceptions::ConnectionError => e # Includes TimeoutError
          raise Unreachable, e.message
        rescue ::Prusalink::Exceptions::AuthenticationError => e
          raise Unauthorized, e.message
        rescue ::Prusalink::Exceptions::Error => e
          raise Error, e.message
        end

        # The `printer` of PrusaLink's /api/version when it names a model ("MK4", "XL"), nil when it's a version
        # number ("1.0.0", "6.2.0+8899") or missing: the MK4, XL and MINI firmware don't send it, and its format isn't
        # documented
        sig { params(printer: T.nilable(String)).returns(T.nilable(String)) }
        def readable_model(printer)
          model = printer.to_s.strip
          model if model.match?(/[[:alpha:]]/) && !model.match?(/\A\d+(\.\d+)+/)
        end

        # The state family of a PrusaLink status (see Printer::StateFamily.for_prusalink)
        sig { params(status: ::Prusalink::Status).returns(Printer::StateFamily) }
        def state_family(status)
          Printer::StateFamily.for_prusalink(status.printer&.state, job: !status.job.nil?)
        end
      end

      sig { override.returns(String) }
      def product_name
        'PrusaLink'
      end

      sig { override.returns(String) }
      def secret_name
        'password'
      end

      sig { override.returns(T::Boolean) }
      def connects_on_its_own?
        true
      end

      sig { override.returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def current_job
        job = use { ::Prusalink::Job.get }
        file = job&.file
        name = file&.display_name || file&.name
        progress = job&.progress
        return nil if name.nil? || progress.nil?

        { name:, progress: progress.to_f }
      end

      # PrusaLink's state, capitalized: "Printing", "Attention", ...
      sig { override.returns(T.nilable(String)) }
      def job_status
        status.printer&.state&.capitalize
      end

      sig { override.returns(Printer::StateFamily) }
      def state_family
        self.class.state_family(status)
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def print_progress
        current = status
        { state_family: self.class.state_family(current), progress: current.job&.progress&.to_f }
      end

      # The Status has the state and the job's id, the Job its file: read only when there is a job
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def live_job
        current = status
        job = use { ::Prusalink::Job.get } if current.job
        file = job&.file
        { state_family: self.class.state_family(current), file_name: file&.display_name || file&.name, job_id: job&.id }
      end

      # e.g. "PrusaLink 2.1.2 (firmware 6.2.0+8899)"
      sig { override.returns(T.nilable(String)) }
      def version
        server = use { ::Prusalink::ServerVersion.get }
        firmware = server.firmware.presence
        ["PrusaLink #{server.version}", firmware && "(firmware #{firmware})"].compact.join(' ')
      end

      # The name set on the printer, or the host of its URL
      sig { override.returns(T::Hash[Symbol, T.nilable(String)]) }
      def identify
        info = use { ::Prusalink::Info.get }
        { name: info&.name.presence || URI(printer.uri.to_s).host, version: }
      end

      # The name and nozzle from the printer's info, the firmware version and model from the server version. The
      # firmware is always Prusa's. The cameras aren't read yet.
      sig { override.returns(ReportedSpecs) }
      def reported_specs
        info = use { ::Prusalink::Info.get }
        server = use { ::Prusalink::ServerVersion.get }
        ReportedSpecs.new(name: info&.name.presence, model: self.class.readable_model(server.printer),
                          firmware: 'prusa_firmware', firmware_version: server.firmware.presence,
                          nozzle_diameter: info&.nozzle_diameter&.to_f)
      end

      # The camera isn't supported yet
      sig { override.returns(T.nilable(String)) }
      def webcam_url
        nil
      end

      sig { override.params(job_id: T.nilable(Integer)).void }
      def pause(job_id: nil)
        id = job_id || current_job_id
        use { ::Prusalink::Job.pause(id) }
      end

      sig { override.params(job_id: T.nilable(Integer)).void }
      def resume(job_id: nil)
        id = job_id || current_job_id
        use { ::Prusalink::Job.resume(id) }
      end

      sig { override.params(job_id: T.nilable(Integer)).void }
      def cancel(job_id: nil)
        id = job_id || current_job_id
        use { ::Prusalink::Job.stop(id) }
      end

      sig { override.void }
      def connect
        raise Error, CONNECTS_ON_ITS_OWN
      end

      sig { override.void }
      def reconnect
        raise Error, CONNECTS_ON_ITS_OWN
      end

      # Uploads the file (G-code or binary G-code, sent as it is) to the root of the first writable storage, replacing
      # a file of the same name. With its own client: large files take much longer than the API client's timeouts.
      sig { override.params(path: String, print: T::Boolean).void }
      def upload(path, print: false)
        storage = T.let(writable_storage.path, String)
        self.class.translate_errors do
          upload_client.use do
            ::Prusalink::Files.upload(path, storage:, path: ::File.basename(path), print_after_upload: print,
                                            overwrite: true)
          end
        end
      end

      # The printer's PrusaLink client, for Printer::Monitor::PrusalinkReader.
      # Raises Prusalink::Exceptions::MissingCredentialsError when the URI or the password is blank.
      sig { returns(::Prusalink::Client) }
      def client
        @client ||= T.let(
          ::Prusalink::Client.new(host: printer.uri.presence, password: printer.secret.presence,
                                  username: printer.username.presence || ::Prusalink::Client::DEFAULT_USERNAME,
                                  open_timeout: OPEN_TIMEOUT, timeout: TIMEOUT),
          T.nilable(::Prusalink::Client)
        )
      end

      private

      # Raises Prusalink::Exceptions::MissingCredentialsError when the URI or the password is blank
      sig { returns(::Prusalink::Client) }
      def upload_client
        @upload_client ||= T.let(
          ::Prusalink::Client.new(host: printer.uri.presence, password: printer.secret.presence,
                                  username: printer.username.presence || ::Prusalink::Client::DEFAULT_USERNAME,
                                  open_timeout: UPLOAD_OPEN_TIMEOUT, timeout: UPLOAD_TIMEOUT),
          T.nilable(::Prusalink::Client)
        )
      end

      # The first available storage that isn't read only: the USB drive on MK4, XL and MINI, the local storage of
      # PrusaLink on a Raspberry Pi. Raises Printer::Backend::Error when there is none (e.g. no USB drive inserted).
      sig { returns(::Prusalink::Storage) }
      def writable_storage
        storages = use { ::Prusalink::Storage.list }
        storages.find { |storage| storage.available? && !storage.read_only? && storage.path.present? } ||
          raise(Error, "#{printer.name} has no writable storage. Insert a USB drive")
      end

      # Raises Printer::Backend::Error when PrusaLink answers without a status
      sig { returns(::Prusalink::Status) }
      def status
        use { ::Prusalink::Status.get } || raise(Error, 'PrusaLink answered without a status')
      end

      # The id of the job under way. Raises NoJob when there is none (e.g. it ended after the state was read).
      sig { returns(Integer) }
      def current_job_id
        id = use { ::Prusalink::Job.get }&.id
        raise NoJob, 'No job under way' if id.nil?

        id
      end

      # rubocop:disable Naming/BlockForwarding, Style/ArgumentsForwarding -- Sorbet sigs need a named block
      sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
      def use(&block)
        self.class.translate_errors { client.use(&block) }
      end
      # rubocop:enable Naming/BlockForwarding, Style/ArgumentsForwarding
    end
  end
end
