# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saves the printer details page in one go: connection and specs. Only the fields sent are written: an omitted
    # field stays as it is, null clears it. The secret is only replaced by a new one (the page never shows it).
    class UpdatePrinter < Base::Mutation
      description 'Changes a printer: only the fields sent are written (omitted: unchanged, null: cleared). The ' \
                  'monitor reconnects with the new credentials on its own.'

      argument :id, ID, required: true
      argument :name, String, required: false
      argument :uri, Types::Url, required: false, description: "The URL of the printer's server"
      argument :username, String, required: false, description: 'The username, for PrusaLink (default: "maker")'
      argument :secret, String, required: false,
                                description: "OctoPrint's API key, or PrusaLink's password. Null or empty keeps " \
                                             'the saved one.'
      argument :specs, InputObjects::PrinterSpecsInput, required: false,
                                                        description: 'The specs to change. Null changes none.'

      field :printer, Types::Printer, null: true, description: 'The printer as saved, null when it was not found'
      field :errors, [String], null: false, description: 'Why it was not saved, empty when it was'

      #: (id: String, **untyped changes) -> Hash[Symbol, untyped]
      def resolve(id:, **changes)
        printer = ::Printer.find_by(id:)
        return { printer: nil, errors: ['Printer not found'] } if printer.nil?

        if printer.update(attributes(changes))
          if printer.saved_change_to_uri?
            forget_api_answers(printer)
            # The new address hasn't been read: if it can't be now, the monitor fills the specs once it answers
            printer.update_column(:specs_filled_at, nil) # rubocop:disable Rails/SkipsModelValidations
            # After forgetting: the specs come from the new address, not from the old one's cached answer
            printer.fill_specs_from_server
          end
          { printer:, errors: [] }
        else
          # The printer as saved, without the rejected changes
          errors = printer.errors.full_messages
          { printer: printer.reload, errors: }
        end
      end

      private

      #: (Hash[Symbol, untyped] changes) -> Hash[Symbol, untyped]
      def attributes(changes)
        specs = changes.delete(:specs)
        changes.delete(:secret) if changes[:secret].blank?
        changes[:uri] = changes[:uri].presence if changes.key?(:uri)
        changes[:username] = changes[:username].presence if changes.key?(:username)
        specs ? changes.merge(specs.to_attributes) : changes
      end

      # The answers cached from the old address (and its disconnected flag) don't apply to the new one: the next read
      # calls the new address
      #: (::Printer printer) -> void
      def forget_api_answers(printer)
        ::Printer::ApiCache.delete_by(printer_id: printer.id)
        ::Printer::Disconnection.delete_by(printer_id: printer.id)
      rescue Redis::BaseError, ConnectionPool::TimeoutError => e
        Rails.logger.error("[updatePrinter] Could not forget the API answers of printer #{printer.id}: #{e.message}")
      end
    end
  end
end
