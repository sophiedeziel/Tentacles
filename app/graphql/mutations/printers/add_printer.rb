# frozen_string_literal: true

module Mutations
  module Printers
    class AddPrinter < Base::Mutation
      description 'Mutation to add a printer configuration'

      argument :backend, Types::PrinterBackend, required: false, default_value: 'octoprint',
                                                replace_null_with_default: true
      argument :name, String, required: true
      argument :uri, String, required: false, description: "The URL of the printer's server"
      argument :username, String, required: false, description: 'The username, for PrusaLink (default: "maker")'
      argument :secret, String, required: false, description: "OctoPrint's API key, or PrusaLink's password"
      argument :octoprint_uri, String, required: false, deprecation_reason: 'Use `uri`'
      argument :octoprint_key, String, required: false, deprecation_reason: 'Use `secret`'

      field :printer, Types::Printer, null: true, description: 'The new printer, null when it is invalid'
      field :errors, [String], null: false, description: 'Why the printer is invalid, empty when it was added'

      # One keyword per argument, as Tapioca generates the signature from the arguments
      def resolve(name:, backend: 'octoprint', uri: nil, username: nil, secret: nil, # rubocop:disable Metrics/ParameterLists
                  octoprint_uri: nil, octoprint_key: nil)
        printer = ::Printer.new(name:, backend:, uri: (uri.presence || octoprint_uri).presence,
                                username: username.presence, secret: (secret.presence || octoprint_key).presence)
        if printer.save
          start_spool(printer)
          printer.fill_specs_from_server
          { printer:, errors: [] }
        else
          { printer: nil, errors: printer.errors.full_messages }
        end
      end

      private

      # The spooler builds a spool for the new printer. The printer is added either way: without it, the spooler only
      # picks the printer up on its next restart.
      def start_spool(printer)
        printer.notify_spooler(:add_printer)
      rescue Redis::BaseError, ConnectionPool::TimeoutError => e
        Rails.logger.error("[addPrinter] Could not publish add_printer for printer #{printer.id}: #{e.message}")
      end
    end
  end
end
