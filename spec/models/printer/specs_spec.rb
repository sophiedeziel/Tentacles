# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Specs, type: :model do
  let(:printer) { build(:printer) }

  it 'leaves every spec unset on a new printer, with no materials and not a favorite' do
    expect(printer).to have_attributes(favorite: false, brand: nil, firmware: nil, bed_shape: nil,
                                       build_volume_x: nil, heated_bed: nil, materials: [])
    expect(printer).to be_valid
  end

  describe 'normalizers' do
    it 'strips brand, model, firmware and firmware version' do
      printer.assign_attributes(brand: '  Prusa Research ', model: "MK4\n", firmware: ' klipper ',
                                firmware_version: ' 6.2.0 ')

      expect(printer).to have_attributes(brand: 'Prusa Research', model: 'MK4', firmware: 'klipper',
                                         firmware_version: '6.2.0')
    end

    it 'turns blank text into nil' do
      printer.assign_attributes(brand: '  ', model: '', firmware: "\t", firmware_version: ' ')

      expect(printer).to have_attributes(brand: nil, model: nil, firmware: nil, firmware_version: nil)
    end

    it 'strips the materials, drops the blank ones and the duplicates' do
      printer.materials = [' PLA', 'PETG ', '', '  ', 'PLA', nil]

      expect(printer.materials).to eq %w[PLA PETG]
    end

    it 'turns nil materials into none' do
      printer.materials = nil

      expect(printer.materials).to eq []
    end

    it 'saves and reads back the materials' do
      printer.update!(materials: %w[PLA ASA])

      expect(Printer.find(printer.id).materials).to eq %w[PLA ASA]
    end
  end

  describe 'validations' do
    it 'accepts a firmware Tentacles does not know' do
      printer.firmware = 'Smoothieware'

      expect(printer).to be_valid
    end

    it 'accepts the bed shapes' do
      expect(Printer::Specs::BED_SHAPES.map { |bed_shape| build(:printer, bed_shape:) }).to all(be_valid)
    end

    it 'refuses another bed shape' do
      printer.bed_shape = 'hexagonal'

      expect(printer).not_to be_valid
      expect(printer.errors[:bed_shape]).to eq ['is not included in the list']
    end

    %i[build_volume_x build_volume_y build_volume_z build_diameter nozzle_diameter].each do |attribute|
      it "refuses a #{attribute} of 0 or less" do
        printer[attribute] = 0

        expect(printer).not_to be_valid
        expect(printer.errors[attribute]).to eq ['must be greater than 0']
      end
    end

    it 'accepts a circular bed with a diameter and a height, without X and Y' do
      printer.assign_attributes(bed_shape: 'circular', build_diameter: 230, build_volume_z: 300)

      expect(printer).to be_valid
    end

    it 'refuses less than one extruder' do
      printer.extruders = 0

      expect(printer).not_to be_valid
      expect(printer.errors[:extruders]).to eq ['must be greater than or equal to 1']
    end

    it 'refuses a fractional number of extruders' do
      printer.extruders = '1.5'

      expect(printer).not_to be_valid
      expect(printer.errors[:extruders]).to eq ['must be an integer']
    end

    %i[max_hotend_temp max_bed_temp].each do |attribute|
      it "accepts a #{attribute} from 0 to 500 °C" do
        expect([0, 500].map { |temperature| build(:printer, attribute => temperature) }).to all(be_valid)
      end

      it "refuses a #{attribute} below 0 or above 500 °C" do
        [-1, 501].each do |temperature|
          printer[attribute] = temperature

          expect(printer).not_to be_valid
          expect(printer.errors[attribute]).to eq ['must be in 0..500']
        end
      end
    end
  end
end
