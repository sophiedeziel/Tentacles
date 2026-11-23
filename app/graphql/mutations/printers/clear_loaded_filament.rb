# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Remove Filament, on the Loaded Filament card of the printer's page
    class ClearLoadedFilament < Base::Mutation
      extend T::Sig

      description "Removes the filament loaded in a slot of a printer: the slot's filament is not set again. A " \
                  'slot with no filament is left as it is. Pushes printerStatusChanged when a filament was removed.'

      argument :printer_id, ID, required: true
      argument :slot, Integer, required: false, default_value: 1, replace_null_with_default: true,
                               description: 'The slot, from 1 (default: 1)'

      field :printer, Types::Printer, null: true, description: 'The printer, null when it was not found'
      field :errors, [Types::UserError], null: false, description: 'Why it was not removed, empty when it was'

      sig { params(printer_id: String, slot: Integer).returns(T::Hash[Symbol, T.untyped]) }
      def resolve(printer_id:, slot: 1)
        printer = ::Printer.find_by(id: printer_id)
        return { printer: nil, errors: [Types::UserError.base('Printer not found')] } if printer.nil?

        removal = ::Printer::FilamentRemoval.new(printer:, slot:)
        { printer:, errors: removal.save ? [] : Types::UserError.from(removal.errors) }
      end
    end
  end
end
