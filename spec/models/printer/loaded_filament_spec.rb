# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::LoadedFilament do
  let(:printer) { create(:printer) }
  let(:filament) { build(:printer_loaded_filament, printer:) }

  it 'has a valid factory, in slot 1' do
    expect(filament).to be_valid
    expect(filament.slot).to eq 1
  end

  describe 'material' do
    it 'is stored normalised' do
      filament.update!(material: ' pla ')

      expect(filament.reload.material).to eq 'PLA'
    end

    it 'refuses a material outside the list' do
      filament.material = 'Wood'

      expect(filament).not_to be_valid
      expect(filament.errors[:material]).to eq ['is not included in the list']
    end

    it 'refuses a blank material' do
      filament.material = nil

      expect(filament).not_to be_valid
      expect(filament.errors).to include(:material)
    end
  end

  describe 'colour' do
    it 'is stored as typed, trimmed, beside its key' do
      filament.update!(colour: '  Galaxy Black ')

      expect(filament.reload).to have_attributes(colour: 'Galaxy Black', colour_key: 'galaxy black')
    end

    it 'gives "Black", "black" and " BLACK " one key, and "Galaxy Black" another' do
      keys = ['Black', 'black', ' BLACK ', 'Galaxy Black'].map { |colour| described_class.new(colour:).colour_key }

      expect(keys).to eq ['black', 'black', 'black', 'galaxy black']
    end

    it 'is required' do
      filament.colour = '  '

      expect(filament).not_to be_valid
      expect(filament.errors[:colour]).to eq ["can't be blank"]
    end

    it 'is at most 40 characters' do
      filament.colour = 'x' * 41

      expect(filament).not_to be_valid
      expect(filament.errors[:colour]).to eq ['is too long (maximum is 40 characters)']
    end
  end

  describe 'slot' do
    it "refuses a slot above the printer's filament slots" do
      filament.slot = 2

      expect(filament).not_to be_valid
      expect(filament.errors[:slot]).to eq ['must be less than or equal to 1']
    end

    it 'accepts every slot of a printer that has several' do
      printer.update!(filament_slots: 2)
      filament.slot = 2

      expect(filament).to be_valid
    end

    it 'refuses slot 0' do
      filament.slot = 0

      expect(filament).not_to be_valid
      expect(filament.errors[:slot]).to eq ['must be greater than or equal to 1']
    end

    it 'holds one filament per slot of a printer' do
      create(:printer_loaded_filament, printer:)

      expect(filament).not_to be_valid
      expect(filament.errors[:slot]).to eq ['has already been taken']
    end

    it 'is enforced by the database too' do
      create(:printer_loaded_filament, printer:)

      expect { filament.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'can be the same on another printer' do
      create(:printer_loaded_filament)

      expect(filament).to be_valid
    end
  end

  describe '#matches?' do
    let(:filament) { build(:printer_loaded_filament, material: 'PLA', colour: 'Black') }

    it 'matches the same material and colour, whatever their spelling' do
      expect(filament.matches?(material: ' pla', colour: 'black ')).to be true
    end

    it 'matches the same material in any colour' do
      expect(filament.matches?(material: 'PLA')).to be true
      expect(filament.matches?(material: 'PLA', colour: nil)).to be true
    end

    it 'does not match another material' do
      expect(filament.matches?(material: 'PETG', colour: 'Black')).to be false
      expect(filament.matches?(material: 'PETG')).to be false
    end

    it 'does not match another colour' do
      expect(filament.matches?(material: 'PLA', colour: 'Galaxy Black')).to be false
    end
  end
end
