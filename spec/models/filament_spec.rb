# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Filament do
  it 'lists the materials by their key' do
    keys = described_class::MATERIALS.map { |material| described_class.material_key(material) }

    expect(keys).to eq described_class::MATERIALS
  end

  it 'suggests default colours that are distinct by key' do
    keys = described_class::DEFAULT_COLOURS.map { |colour| described_class.colour_key(colour) }

    expect(keys).to eq keys.uniq
  end

  describe '.colour_suggestions' do
    def load_filament(colour, updated_at: Time.current)
      create(:printer_loaded_filament, printer: create(:printer), colour:, updated_at:)
    end

    it 'is the default colours when no filament is loaded' do
      expect(described_class.colour_suggestions).to eq described_class::DEFAULT_COLOURS
    end

    it 'adds the colours in use after the defaults, alphabetical by key, once per key' do
      load_filament('silk gold')
      load_filament('Army Green', updated_at: 1.day.ago)
      load_filament('army  GREEN', updated_at: 2.days.ago)
      load_filament('BLACK')

      expect(described_class.colour_suggestions).to eq(described_class::DEFAULT_COLOURS + ['Army Green', 'silk gold'])
    end
  end

  describe '.material_key' do
    it 'strips and upcases' do
      expect(described_class.material_key(" petg\n")).to eq 'PETG'
    end

    it 'turns nil into an empty key' do
      expect(described_class.material_key(nil)).to eq ''
    end
  end

  describe '.colour_key' do
    it 'gives "Black", "black" and " BLACK " the same key' do
      keys = ['Black', 'black', ' BLACK '].map { |colour| described_class.colour_key(colour) }

      expect(keys).to eq %w[black black black]
    end

    it 'gives "Galaxy Black" another key than "Black"' do
      expect(described_class.colour_key('Galaxy Black')).not_to eq described_class.colour_key('Black')
    end

    it 'trims, single-spaces and lower-cases' do
      expect(described_class.colour_key("  Galaxy \t BLACK ")).to eq 'galaxy black'
    end

    it 'normalises Unicode compatibility forms (NFKC)' do
      expect(described_class.colour_key('Ｂｌａｃｋ')).to eq 'black' # full-width letters
    end
  end
end
