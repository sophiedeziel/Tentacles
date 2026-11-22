# frozen_string_literal: true

module Mutations
  module Printers
    # Removes a printer through Printer::Removal. Clients evict the printer from their cache with removedPrinterId.
    class RemovePrinter < Base::Mutation
      description 'Removes a printer from Tentacles, with its jobs (queued, under way and finished) and its ' \
                  'dashboard widgets. Its files stay in the library. The printer itself is not contacted: a print ' \
                  'under way keeps running.'

      argument :id, ID, required: true

      field :removed_printer_id, ID, null: true, description: 'The id of the removed printer, null when it was not'
      field :errors, [String], null: false, description: 'Why the printer was not removed, empty when it was'

      def resolve(id:)
        printer = ::Printer.find_by(id:)
        return { removed_printer_id: nil, errors: ['Printer not found'] } if printer.nil?

        # false when the printer changed while removing it (see Printer::Removal::CONFLICTS)
        removal = ::Printer::Removal.new(printer:)
        return { removed_printer_id: nil, errors: removal.errors.full_messages } unless removal.save

        { removed_printer_id: printer.id, errors: [] }
      end
    end
  end
end
