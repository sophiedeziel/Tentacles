# typed: strict
# frozen_string_literal: true

module PrinterBackends
  # The interface of a printer API adapter. Adapters return plain Ruby values (strings, hashes, PrinterStateFamily),
  # never the client gem's objects, and raise PrinterBackends::Error subclasses instead of the gem's errors.
  # Each adapter holds its own clients: nothing global is configured.
  class Base
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(Printer) }
    attr_reader :printer

    sig { params(printer: Printer).void }
    def initialize(printer)
      @printer = printer
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
    sig { abstract.returns(PrinterStateFamily) }
    def state_family; end

    # The state family and the completion (in percent, nil when unknown) of the job, read in a single request:
    # `{ state_family: PrinterStateFamily::Printing, progress: 42.1 }`
    sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
    def print_progress; end

    # The state family and the job under way, read together, for the printer actions:
    # `{ state_family: PrinterStateFamily::Printing, file_name: 'cube.gcode', job_id: 7 }`. `file_name` is the name
    # the monitor reports (PrinterStatus#file_name), so that an action can check it against the file the user
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
