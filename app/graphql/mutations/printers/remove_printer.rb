# frozen_string_literal: true

module Mutations
  module Printers
    # Removes a printer through Printers::Remove. Clients evict the printer from their cache with removedPrinterId.
    class RemovePrinter < Base::Mutation
      description 'Removes a printer from Tentacles, with its jobs (queued, under way and finished) and its ' \
                  'dashboard widgets. Its files stay in the library. The printer itself is not contacted: a print ' \
                  'under way keeps running.'

      argument :id, ID, required: true

      field :removed_printer_id, ID, null: true, description: 'The id of the removed printer, null when it was not'
      field :errors, [String], null: false, description: 'Why the printer was not removed, empty when it was'

      # A concurrent change (e.g. a dashboard saved with a widget of this printer): nothing was removed
      CONFLICTS = [ActiveRecord::InvalidForeignKey, ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout,
                   ActiveRecord::RecordNotDestroyed].freeze

      def resolve(id:)
        printer = ::Printer.find_by(id:)
        return failure('Printer not found') if printer.nil?

        ::Printers::Remove.call(printer)
        { removed_printer_id: printer.id, errors: [] }
      rescue *CONFLICTS
        failure('The printer changed while removing it, try again')
      end

      private

      def failure(error)
        { removed_printer_id: nil, errors: [error] }
      end
    end
  end
end
