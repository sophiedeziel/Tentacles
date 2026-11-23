# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saved on its own, as soon as the star is clicked (fleet list and printer details)
    class SetPrinterFavorite < Base::Mutation
      description 'Marks a printer as a favorite, or not. Favorites come first in the fleet list.'

      argument :id, ID, required: true
      argument :favorite, Boolean, required: true

      field :printer, Types::Printer, null: true, description: 'The printer, null when it was not found'
      field :errors, [String], null: false, description: 'Why it was not saved, empty when it was'

      #: (id: String, favorite: bool) -> Hash[Symbol, untyped]
      def resolve(id:, favorite:)
        printer = ::Printer.find_by(id:)
        return { printer: nil, errors: ['Printer not found'] } if printer.nil?
        return { printer:, errors: [] } if printer.update(favorite:)

        { printer: printer.reload, errors: printer.errors.full_messages }
      end
    end
  end
end
