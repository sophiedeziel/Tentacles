# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Base for the mutations that send a command to a printer (pausePrint, connectPrinter, ...). Each one saves a
    # Printer::Command (Printer::Pause, Printer::Connection, ...), which checks the printer's live state, sends the
    # command and refreshes the printer's status.
    #
    # Never raises for printer API or network failures: they come back as readable messages in `errors`.
    #
    # Subclasses implement `command_class`, and declare the expectations their command takes (`expectedFileName`,
    # `expectedJobId`) as arguments.
    # @abstract
    class PrinterAction < Base::Mutation
      argument :printer_id, ID, required: true

      field :success, Boolean, null: false
      field :errors, [String], null: false
      field :printer, Types::Printer, null: true

      # The expectations are the subclass's arguments (expected_file_name, expected_job_id)
      def resolve(printer_id:, **expectations)
        printer = ::Printer.find(printer_id)
        command = command_class.new(printer:, **expectations)
        return { success: true, errors: [], printer: } if command.save

        { success: false, errors: command.errors.full_messages, printer: }
      rescue ActiveRecord::RecordNotFound
        { success: false, errors: ['Printer not found'], printer: nil }
      end

      private

      # The Printer::Command the mutation saves
      # @abstract
      #: -> singleton(::Printer::Command)
      def command_class = super
    end
  end
end
