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
  class Backend < ApplicationModel
    extend T::Helpers

    abstract!

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

    # The Printer whose server this talks to
    attribute :printer

    class << self
      extend T::Sig

      # The adapter of the printer's backend
      sig { params(printer: Printer).returns(Printer::Backend) }
      def for(printer)
        case printer.backend
        when 'octoprint' then Octoprint.new(printer:)
        when 'prusalink' then Prusalink.new(printer:)
        else raise ArgumentError, "Unknown printer backend #{printer.backend.inspect}"
        end
      end
    end

    # The server's name, for the messages shown to the user: "OctoPrint", "PrusaLink"
    sig { abstract.returns(String) }
    def product_name; end

    # What `printers.secret` holds, for the messages shown to the user: "API key", "password"
    sig { abstract.returns(String) }
    def secret_name; end

    # Whether the server connects to the printer by itself, so that #connect and #reconnect make no sense
    sig { returns(T::Boolean) }
    def connects_on_its_own?
      false
    end

    # The file and completion (in percent) of the job under way: `{ name: 'cube.gcode', progress: 42.1 }`.
    # nil when there is no job.
    sig { abstract.returns(T.nilable(T::Hash[Symbol, T.untyped])) }
    def current_job; end

    # The printer's state, as the API words it ("Operational", "Printing", ...)
    sig { abstract.returns(T.nilable(String)) }
    def job_status; end

    # The printer's state family
    sig { abstract.returns(Printer::StateFamily) }
    def state_family; end

    # The state family and the completion (in percent, nil when unknown) of the job, read in a single request:
    # `{ state_family: Printer::StateFamily::Printing, progress: 42.1 }`
    sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
    def print_progress; end

    # The state family and the job under way, read together, for the printer commands (read as a Printer::LiveJob):
    # `{ state_family: Printer::StateFamily::Printing, file_name: 'cube.gcode', job_id: 7 }`. `file_name` is the name
    # the monitor reports (Printer::Status#file_name), so that a command can check it against the file the user
    # confirmed. `job_id` is the backend's id of that job, to pass to #pause, #resume and #cancel (nil for the
    # backends without job ids, like OctoPrint). Both are nil when no job is loaded.
    sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
    def live_job; end

    # The server's name and version, e.g. "OctoPrint 1.11.2"
    sig { abstract.returns(T.nilable(String)) }
    def version; end

    # The printer's name and the server version: `{ name: 'Prusa MK4', version: 'OctoPrint 1.11.2' }`.
    # Raises Unauthorized or Unreachable, so that a form can tell why the printer can't be added.
    sig { abstract.returns(T::Hash[Symbol, T.nilable(String)]) }
    def identify; end

    # What the server reports about the printer (its name, model, build volume, ...), to fill the specs left blank.
    # Raises like #identify.
    sig { abstract.returns(ReportedSpecs) }
    def reported_specs; end

    # The URL of the webcam stream, or nil when there is none
    sig { abstract.returns(T.nilable(String)) }
    def webcam_url; end

    # The job commands act on the job under way. `job_id` (from #live_job) makes them act on that job only, rather
    # than on one that started since; without it, the backends that need an id read the current one.
    sig { abstract.params(job_id: T.nilable(Integer)).void }
    def pause(job_id: nil); end

    sig { abstract.params(job_id: T.nilable(Integer)).void }
    def resume(job_id: nil); end

    sig { abstract.params(job_id: T.nilable(Integer)).void }
    def cancel(job_id: nil); end

    # Connects the server to the printer
    sig { abstract.void }
    def connect; end

    # Closes the server's connection to the printer, then opens it again
    sig { abstract.void }
    def reconnect; end

    # Uploads a G-code file, and starts printing it when `print` is true.
    # Errors (including timeouts) are raised: an upload must not fail silently.
    sig { abstract.params(path: String, print: T::Boolean).void }
    def upload(path, print: false); end
  end
end
