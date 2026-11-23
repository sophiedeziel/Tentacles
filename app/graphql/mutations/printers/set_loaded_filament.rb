# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saved from the Loaded Filament card of the printer's page, on its own (not with the page's specs)
    class SetLoadedFilament < Base::Mutation
      description "Sets the filament loaded in a slot of a printer, replacing the slot's filament. Pushes " \
                  'printerStatusChanged.'

      argument :printer_id, ID, required: true
      argument :material, String, required: true, description: 'One of filamentMaterials (any case)'
      argument :colour, String, required: true, description: 'As it should be displayed, e.g. "Galaxy Black"'
      argument :slot, Integer, required: false, default_value: 1, replace_null_with_default: true,
                               description: 'The slot, from 1 (default: 1)'

      field :printer, Types::Printer, null: true, description: 'The printer, null when it was not found'
      field :errors, [Types::UserError], null: false, description: 'Why it was not saved, empty when it was'

      #: (
      #|   printer_id: String,
      #|   material: String,
      #|   colour: String,
      #|   ?slot: Integer
      #| ) -> Hash[Symbol, untyped]
      def resolve(printer_id:, material:, colour:, slot: 1)
        printer = ::Printer.find_by(id: printer_id)
        return { printer: nil, errors: [Types::UserError.base('Printer not found')] } if printer.nil?

        change = ::Printer::FilamentChange.new(printer:, material:, colour:, slot:)
        { printer:, errors: change.save ? [] : Types::UserError.from(change.errors) }
      end
    end
  end
end
