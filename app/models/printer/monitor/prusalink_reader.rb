# typed: true
# frozen_string_literal: true

class Printer
  module Monitor
    # Reads a printer's state from its PrusaLink with the printer's own client (see Printer::Backend::Prusalink#client).
    #
    #   Printer::Monitor::PrusalinkReader.new(printer:).status_attributes # => { state_family:, state_text:, ... }
    #
    # One Status request per tick gives the state, the temperatures, the progress and the time left. The file name
    # needs a Job request, sent only when the job changes: the name is kept for the job's id. The PrusaLink errors
    # that escape #status_attributes are raised as Printer::Backend errors.
    class PrusalinkReader < ApplicationModel
      include Logging
      include Reader

      # Longest text kept from PrusaLink (state, file name)
      MAX_TEXT_LENGTH = 255

      attribute :printer

      #: (**untyped attributes) -> void
      def initialize(**attributes)
        super
        # The id of the last job seen and its file name: the reader's own state (see #file_name)
        @job_file = nil #: [Integer?, String?]?
      end

      # The job and temperatures, as Printer::Status attributes.
      # Raises Printer::Backend::Error (e.g. Unreachable) when PrusaLink can't be reached.
      # @override
      #: -> Hash[Symbol, untyped]
      def status_attributes
        Printer::Backend::Prusalink.translate_errors do
          status = api { Prusalink::Status.get }
          raise Printer::Backend::Error, 'PrusaLink answered without a status' if status.nil?

          state_attributes(status).merge(job_attributes(status.job), temperatures(status.printer))
        end
      end

      # PrusaLink's camera isn't supported yet
      # @override
      #: -> Printer::Status::Camera
      def camera
        Printer::Status::Camera.new(enabled: false)
      end

      private

      #: (Prusalink::Status status) -> Hash[Symbol, untyped]
      def state_attributes(status)
        {
          state_family: Printer::Backend::Prusalink.state_family(status),
          state_text: text(status.printer&.state&.capitalize) || Printer::Status::UNKNOWN_STATE_TEXT,
          error_text: nil
        }
      end

      #: (Prusalink::Status::Job? job) -> Hash[Symbol, untyped]
      def job_attributes(job)
        {
          file_name: text(file_name(job)),
          progress: job&.progress&.to_f,
          print_time_left: job&.time_remaining&.round
        }
      end

      #: (Prusalink::Status::Printer? printer) -> Hash[Symbol, untyped]
      def temperatures(printer)
        return { hotend: nil, bed: nil } if printer.nil?

        {
          hotend: to_temperature(printer.temp_nozzle, printer.target_nozzle),
          bed: to_temperature(printer.temp_bed, printer.target_bed)
        }
      end

      # The file of the job, read once per job: the Status only has the job's id
      #: (Prusalink::Status::Job? job) -> String?
      def file_name(job)
        if job.nil?
          @job_file = nil
          return nil
        end

        job_file = @job_file
        return job_file.last if job_file && job_file.first == job.id

        read_file_name(job.id)
      end

      #: (Integer? job_id) -> String?
      def read_file_name(job_id)
        job = api { Prusalink::Job.get }
        return nil if job.nil? # The job ended in the meantime: try again on the next tick

        file = job.file
        name = file&.display_name || file&.name
        @job_file = [job_id, name]
        name
      # XL firmware answers with invalid JSON for a job whose file was deleted: the job goes on without its name
      rescue Prusalink::Exceptions::InvalidResponseError => e
        log_exception('Failed to read the job', e)
        @job_file = [job_id, nil]
        nil
      end

      #: (
      #|   Numeric? actual,
      #|   Numeric? target
      #| ) -> Printer::Status::Temperature?
      def to_temperature(actual, target)
        return nil if actual.nil? && target.nil?

        Printer::Status::Temperature.new(actual: actual&.to_f, target: target&.to_f)
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

      # Raises Prusalink::Exceptions::MissingCredentialsError when the URI or the password is blank
      #: -> Prusalink::Client
      def client
        T.cast(printer.api, Printer::Backend::Prusalink).client
      end
    end
  end
end
