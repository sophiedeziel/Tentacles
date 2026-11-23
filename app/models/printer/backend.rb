# typed: strict
# frozen_string_literal: true

class Printer
  # The API of a printer's server: the interface of the adapters, one per `printers.backend` (Octoprint, Prusalink).
  # Adapters return plain Ruby values (strings, hashes, Printer::StateFamily), never the client gem's objects, and
  # raise Printer::Backend::Error subclasses instead of the gem's errors. Each adapter holds its own clients: nothing
  # global is configured.
  #
  #   Printer::Backend.for(printer).state_family         # => Printer::StateFamily::Operational
  #   Printer::Backend::Prusalink.new(printer:).identify # => { name: 'Prusa MK4', version: 'PrusaLink 2.1.2 ...' }
  #
  # Use Printer#api rather than building one: it memoizes the adapter until the credentials change.
  #
  # An adapter has nothing to save (#save raises NotImplementedError): it's the connection the other models go through,
  # like ActiveRecord's connection adapters. Missing credentials aren't validated up front: the adapter of a printer
  # without them still names its product and its secret (for the messages), and its requests raise MissingCredentials.
  # @abstract
  class Backend < ApplicationModel
    self.abstract_class = true

    # Base of the errors the adapters raise. Translated from the client gems' errors, with the same message.
    class Error < StandardError; end
    # The printer can't be reached (connection refused, DNS failure, timeout, ...)
    class Unreachable < Error; end
    # The printer rejected the credentials
    class Unauthorized < Error; end
    # The printer has no URI or no secret
    class MissingCredentials < Error; end
    # A job command (pause, resume, cancel) was sent while the printer has no job
    class NoJob < Error; end

    # The stored secret can't be decrypted (e.g. SECRET_KEY_BASE changed): the credentials must be entered again
    class UnreadableCredentials < MissingCredentials
      MESSAGE = "Stored credentials can't be read, re-enter them"
    end

    # The adapter of each `printers.backend`, the only list of the backends: Printer::BACKENDS is its keys and each
    # adapter names its monitor reader (.reader_class). Adding a backend is one entry here. Class names rather than
    # classes, so that loading Backend doesn't load the adapters (which need Backend): .adapter_class autoloads them.
    ADAPTERS = {
      'octoprint' => 'Printer::Backend::Octoprint',
      'prusalink' => 'Printer::Backend::Prusalink'
    }.freeze #: Hash[String, String]

    # A monitor reader class: built like the other models (`.new(printer:)`), its instances are Readers
    ReaderClass = T.type_alias { T.all(T.class_of(ApplicationModel), T::Class[Printer::Monitor::Reader]) }

    # The Printer whose server this talks to
    attribute :printer

    class << self
      # The adapter of the printer's backend
      #: (Printer printer) -> Printer::Backend
      def for(printer)
        adapter_class(printer.backend).new(printer:)
      end

      # The adapter class of a backend: `Printer::Backend.adapter_class('prusalink') # => Printer::Backend::Prusalink`
      #: (String? backend) -> singleton(Printer::Backend)
      def adapter_class(backend)
        name = ADAPTERS[backend.to_s]
        raise ArgumentError, "Unknown printer backend #{backend.inspect}" unless name

        name.constantize #: as singleton(Printer::Backend)
      end

      # The class of the backend's monitor reader (see Printer::Monitor::Reader.for)
      # @abstract
      #: -> Printer::Backend::ReaderClass
      def reader_class = super
    end

    # The server's name, for the messages shown to the user: "OctoPrint", "PrusaLink"
    # @abstract
    #: -> String
    def product_name = super

    # What `printers.secret` holds, for the messages shown to the user: "API key", "password"
    # @abstract
    #: -> String
    def secret_name = super

    # Whether the server connects to the printer by itself, so that #connect and #reconnect make no sense
    #: -> bool
    def connects_on_its_own?
      false
    end

    # The file and completion (in percent) of the job under way: `{ name: 'cube.gcode', progress: 42.1 }`.
    # nil when there is no job.
    # @abstract
    #: -> Hash[Symbol, untyped]?
    def current_job = super

    # The printer's state, as the API words it ("Operational", "Printing", ...)
    # @abstract
    #: -> String?
    def job_status = super

    # The printer's state family
    # @abstract
    #: -> Printer::StateFamily
    def state_family = super

    # The state family and the completion (in percent, nil when unknown) of the job, read in a single request:
    # `{ state_family: Printer::StateFamily::Printing, progress: 42.1 }`
    # @abstract
    #: -> Hash[Symbol, untyped]
    def print_progress = super

    # The state family and the job under way, read together, for the printer commands (read as a Printer::LiveJob):
    # `{ state_family: Printer::StateFamily::Printing, file_name: 'cube.gcode', job_id: 7 }`. `file_name` is the name
    # the monitor reports (Printer::Status#file_name), so that a command can check it against the file the user
    # confirmed. `job_id` is the backend's id of that job, to pass to #pause, #resume and #cancel (nil for the
    # backends without job ids, like OctoPrint). Both are nil when no job is loaded.
    # @abstract
    #: -> Hash[Symbol, untyped]
    def live_job = super

    # The server's name and version, e.g. "OctoPrint 1.11.2"
    # @abstract
    #: -> String?
    def version = super

    # The printer's name and the server version: `{ name: 'Prusa MK4', version: 'OctoPrint 1.11.2' }`.
    # Raises Unauthorized or Unreachable, so that a form can tell why the printer can't be added.
    # @abstract
    #: -> Hash[Symbol, String?]
    def identify = super

    # What the server reports about the printer (its name, model, build volume, ...), to fill the specs left blank.
    # Raises like #identify.
    # @abstract
    #: -> ReportedSpecs
    def reported_specs = super

    # The URL of the webcam stream, or nil when there is none
    # @abstract
    #: -> String?
    def webcam_url = super

    # The job commands act on the job under way. `job_id` (from #live_job) makes them act on that job only, rather
    # than on one that started since; without it, the backends that need an id read the current one.
    # @abstract
    #: (?job_id: Integer?) -> void
    def pause(job_id: nil) = super

    # @abstract
    #: (?job_id: Integer?) -> void
    def resume(job_id: nil) = super

    # @abstract
    #: (?job_id: Integer?) -> void
    def cancel(job_id: nil) = super

    # Connects the server to the printer
    # @abstract
    #: -> void
    def connect = super

    # Closes the server's connection to the printer, then opens it again
    # @abstract
    #: -> void
    def reconnect = super

    # Uploads a G-code file, and starts printing it when `print` is true.
    # Errors (including timeouts) are raised: an upload must not fail silently.
    # @abstract
    #: (String path, ?print: bool) -> void
    def upload(path, print: false) = super
  end
end
