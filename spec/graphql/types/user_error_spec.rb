# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::UserError do
  describe '.from' do
    let(:errors) { ActiveModel::Errors.new(Printer::LoadedFilament.new) }

    it 'names the field in camelCase and gives the full message' do
      errors.add(:colour, :blank)
      errors.add(:colour_key, :invalid)

      expect(described_class.from(errors)).to eq(
        [{ field: 'colour', message: "Colour can't be blank" },
         { field: 'colourKey', message: 'Colour key is invalid' }]
      )
    end

    it 'has no field for a base error' do
      errors.add(:base, 'Printer is busy')

      expect(described_class.from(errors)).to eq([{ field: nil, message: 'Printer is busy' }])
    end

    it 'is empty when there is no error' do
      expect(described_class.from(errors)).to eq([])
    end
  end
end
