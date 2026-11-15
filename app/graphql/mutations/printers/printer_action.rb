# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Base for the mutations that send a command to a printer's OctoPrint (pausePrint, connectPrinter, ...).
    #
    # Each action re-reads the printer's LIVE state from OctoPrint first and refuses, without sending anything, when
    # the printer isn't in a state that allows it. After the command, one monitor tick runs inline so that the new
    # state is pushed to the subscribers before the response returns.
    #
    # Never raises for OctoPrint or network failures: they come back as readable messages in `errors`.
    #
    # Subclasses implement:
    # - `refusal(printer, family)`: the error message when the action isn't allowed in that state family, else nil
    # - `send_command(printer)`: the OctoPrint call(s), run with the printer's own client
    class PrinterAction < Base::Mutation
      extend T::Sig
      extend T::Helpers

      abstract!

      argument :printer_id, ID, required: true

      field :success, Boolean, null: false
      field :errors, [String], null: false
      field :printer, Types::Printer, null: true

      def resolve(printer_id:)
        run(::Printer.find(printer_id))
      rescue ActiveRecord::RecordNotFound
        { success: false, errors: ['Printer not found'], printer: nil }
      end

      private

      # The error message when the action isn't allowed in that state family, or nil when it is
      sig { abstract.params(printer: ::Printer, family: PrinterStateFamily).returns(T.nilable(String)) }
      def refusal(printer, family); end

      # Sends the command to OctoPrint. Runs inside the printer's own client (see Printer#octoprint_client).
      sig { abstract.params(printer: ::Printer).void }
      def send_command(printer); end

      # Whether to run a monitor tick after a successful command
      sig { returns(T::Boolean) }
      def refresh_after_command?
        true
      end

      sig { params(printer: ::Printer).returns(T::Hash[Symbol, T.untyped]) }
      def run(printer)
        error = printer.octoprint_client.use { perform(printer) }
        return failure(printer, error) if error

        PrinterMonitor.refresh(printer) if refresh_after_command?
        { success: true, errors: [], printer: }
      rescue Octoprint::Exceptions::Error, JSON::ParserError, KeyError => e
        failure(printer, octoprint_error_message(printer, e))
      end

      # Checks the live state, then sends the command when it's allowed. Returns the refusal message, if any.
      sig { params(printer: ::Printer).returns(T.nilable(String)) }
      def perform(printer)
        family = PrinterStateFamily.for(Octoprint::Job.get.state)
        message = refusal(printer, family)
        send_command(printer) if message.nil?
        message
      end

      sig { params(printer: ::Printer, error: String).returns(T::Hash[Symbol, T.untyped]) }
      def failure(printer, error)
        { success: false, errors: [error], printer: }
      end

      sig { params(printer: ::Printer, error: StandardError).returns(String) }
      def octoprint_error_message(printer, error)
        case error
        when Octoprint::Exceptions::MissingCredentialsError
          "#{printer.name} has no OctoPrint URL or API key"
        when Octoprint::Exceptions::ConnectionError
          "Could not reach #{printer.name}'s OctoPrint: #{redact(printer, error.message)}"
        when Octoprint::Exceptions::Error
          "#{printer.name}'s OctoPrint returned an error: #{redact(printer, error.message)}"
        else # JSON::ParserError, KeyError: the URL answers, but not like OctoPrint (e.g. an HTML page)
          "#{printer.name}'s OctoPrint URL does not answer like an OctoPrint server"
        end
      end

      # Never echo the API key back, whatever ends up in an error message
      sig { params(printer: ::Printer, message: String).returns(String) }
      def redact(printer, message)
        key = printer.octoprint_key
        key.present? ? message.gsub(key, '[FILTERED]') : message
      end
    end
  end
end
