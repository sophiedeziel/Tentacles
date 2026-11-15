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
        job = printer.api.live_job
        message = refusal(printer, job.fetch(:state_family)) || unexpected_job(printer, job)
        send_command(printer) if message.nil?
        message
      end

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
        case error
        when PrinterBackends::UnreadableCredentials
          "#{printer.name}'s stored OctoPrint API key can't be read, re-enter it"
        when PrinterBackends::MissingCredentials
          "#{printer.name} has no OctoPrint URL or API key"
        when URI::InvalidURIError
          "#{printer.name} has an invalid OctoPrint URL"
        when PrinterBackends::Unreachable
          "Could not reach #{printer.name}'s OctoPrint: #{redact(printer, error.message)}"
        when PrinterBackends::Error
          "#{printer.name}'s OctoPrint returned an error: #{redact(printer, error.message)}"
        else # JSON::ParserError, KeyError: the URL answers, but not like OctoPrint (e.g. an HTML page)
          "#{printer.name}'s OctoPrint URL does not answer like an OctoPrint server"
        end
      end

      # Never echo the API key back, whatever ends up in an error message
      sig { params(printer: ::Printer, message: String).returns(String) }
      def redact(printer, message)
        key = printer.readable_secret
        key.present? ? message.gsub(key, '[FILTERED]') : message
      end
    end
  end
end
