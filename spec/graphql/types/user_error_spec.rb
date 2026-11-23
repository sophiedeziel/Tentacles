# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::UserError do
  it 'has a nullable field and a non-null message' do
    signatures = described_class.fields.transform_values { |field| field.type.to_type_signature }

    expect(signatures).to eq('field' => 'String', 'message' => 'String!')
  end

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

  describe '.base' do
    it 'has no field' do
      expect(described_class.base('Printer not found')).to eq(field: nil, message: 'Printer not found')
    end
  end
end
