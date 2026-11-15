# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Base for the mutations that send a command to a printer (pausePrint, connectPrinter, ...).
    #
    # Each action re-reads the printer's LIVE state from its API first and refuses, without sending anything, when
    # the printer isn't in a state that allows it. After the command, one monitor tick runs inline so that the new
    # state is pushed to the subscribers before the response returns.
    #
    # Never raises for printer API or network failures: they come back as readable messages in `errors`.
    #
    # Subclasses implement:
    # - `refusal(printer, family)`: the error message when the action isn't allowed in that state family, else nil
    # - `send_command(printer)`: the command, sent through `printer.api`
    class PrinterAction < Base::Mutation
      extend T::Sig
      extend T::Helpers

      abstract!

      argument :printer_id, ID, required: true

      field :success, Boolean, null: false
      field :errors, [String], null: false
      field :printer, Types::Printer, null: true

      # The expectations are only passed by the subclasses that declare them (see unexpected_job)
      def resolve(printer_id:, expected_file_name: nil, expected_job_id: nil)
        @expected_file_name = T.let(expected_file_name, T.nilable(String))
        @expected_job_id = T.let(expected_job_id, T.nilable(String))
        run(::Printer.find(printer_id))
      rescue ActiveRecord::RecordNotFound
        { success: false, errors: ['Printer not found'], printer: nil }
      end

      private

      # The error message when the action isn't allowed in that state family, or nil when it is
      sig { abstract.params(printer: ::Printer, family: PrinterStateFamily).returns(T.nilable(String)) }
      def refusal(printer, family); end

      # Sends the command, e.g. `printer.api.pause` (see Printer#api)
      sig { abstract.params(printer: ::Printer).void }
      def send_command(printer); end

      # Whether the action connects the server to the printer. Refused, without reading the state, for the backends
      # that connect on their own (see PrinterBackends::Base#connects_on_its_own?).
      sig { returns(T::Boolean) }
      def connection_command?
        false
      end

      # Whether to run a monitor tick after a successful command
      sig { returns(T::Boolean) }
      def refresh_after_command?
        true
      end

      sig { params(printer: ::Printer).returns(T::Hash[Symbol, T.untyped]) }
      def run(printer)
        error = perform(printer)
        return failure(printer, error) if error

        PrinterMonitor.refresh(printer) if refresh_after_command?
        { success: true, errors: [], printer: }
      # Besides our own bugs: the adapter's errors, answers that aren't OctoPrint's (HTML: JSON::ParserError, no
      # `error` key: KeyError) and a malformed URL. The adapter wraps the network errors.
      rescue PrinterBackends::Error, JSON::ParserError, KeyError, URI::InvalidURIError => e
        failure(printer, api_error_message(printer, e))
      end

      # Checks the live state (and the job the user confirmed, when given), then sends the command when it's
      # allowed. Returns the refusal message, if any.
      sig { params(printer: ::Printer).returns(T.nilable(String)) }
      def perform(printer)
        api = printer.api
        return "#{api.product_name} printers connect on their own" if connection_command? && api.connects_on_its_own?

        job = api.live_job
        @live_job_id = T.let(job[:job_id], T.nilable(Integer))
        message = refusal(printer, job.fetch(:state_family)) || unexpected_job(printer, job)
        send_command(printer) if message.nil?
        message
      end

      # The id of the job #perform checked, for the job commands (`printer.api.pause(job_id: live_job_id)`): the
      # command goes to that job, not to one that started since. nil for the backends without job ids (OctoPrint).
      sig { returns(T.nilable(Integer)) }
      attr_reader :live_job_id

      # The error message when the printer's live job isn't the one the user confirmed (`expectedFileName`, the
      # file the screen showed), or nil. A stale screen must not pause or cancel another print. `job` is
      # `printer.api.live_job`, whose file name is the one the monitor reports (PrinterStatus#file_name).
      sig { params(printer: ::Printer, job: T::Hash[Symbol, T.untyped]).returns(T.nilable(String)) }
      def unexpected_job(printer, job)
        expected = @expected_file_name
        return if expected.nil?

        current = job[:file_name]
        return if current == expected

        current ? "#{printer.name} is now printing #{current}" : "#{printer.name} is no longer printing #{expected}"
      end

      sig { params(printer: ::Printer, error: String).returns(T::Hash[Symbol, T.untyped]) }
      def failure(printer, error)
        { success: false, errors: [error], printer: }
      end

      sig { params(printer: ::Printer, error: StandardError).returns(String) }
      def api_error_message(printer, error)
        api = printer.api
        product = api.product_name
        case error
        when PrinterBackends::UnreadableCredentials
          "#{printer.name}'s stored #{product} #{api.secret_name} can't be read, re-enter it"
        when PrinterBackends::MissingCredentials
          "#{printer.name} has no #{product} URL or #{api.secret_name}"
        when URI::InvalidURIError
          "#{printer.name} has an invalid #{product} URL"
        when PrinterBackends::NoJob
          "#{printer.name} has no job under way"
        when PrinterBackends::Unreachable
          "Could not reach #{printer.name}'s #{product}: #{redact(printer, error.message)}"
        when PrinterBackends::Error
          "#{printer.name}'s #{product} returned an error: #{redact(printer, error.message)}"
        else # JSON::ParserError, KeyError: the URL answers, but not like the server (e.g. an HTML page)
          "#{printer.name}'s #{product} URL does not answer like #{product}"
        end
      end

      # Never echo the API key or password back, whatever ends up in an error message
      sig { params(printer: ::Printer, message: String).returns(String) }
      def redact(printer, message)
        key = printer.readable_secret
        key.present? ? message.gsub(key, '[FILTERED]') : message
      end
    end
  end
end
