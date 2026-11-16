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

  describe '#fill_blank_specs' do
    let(:printer) { create(:printer, :prusalink, model: 'Custom MK4', heated_bed: false) }
    let(:reported) do
      PrinterBackends::ReportedSpecs.new(name: 'Workshop XL', model: 'MK4', firmware: 'prusa_firmware',
                                         nozzle_diameter: 0.6, heated_bed: true, extruders: 1)
    end

    it 'fills the nil columns only, and saves them' do
      expect(printer.fill_blank_specs(reported)).to contain_exactly('firmware', 'nozzle_diameter', 'extruders')

      expect(printer.reload).to have_attributes(name: 'Printer', model: 'Custom MK4', heated_bed: false,
                                                firmware: 'prusa_firmware', nozzle_diameter: 0.6, extruders: 1,
                                                brand: nil, build_volume_x: nil, materials: [])
    end

    it 'leaves nil a column that refuses the reported value' do
      reported = PrinterBackends::ReportedSpecs.new(nozzle_diameter: 0.0, extruders: 2)

      expect(printer.fill_blank_specs(reported)).to eq ['extruders']
      expect(printer.reload).to have_attributes(nozzle_diameter: nil, extruders: 2)
    end

    it 'fills nothing when every reported column is set' do
      printer.update!(firmware: 'marlin', nozzle_diameter: 0.4, extruders: 2)

      expect(printer.fill_blank_specs(reported)).to eq []
      expect(printer.reload).to have_attributes(firmware: 'marlin', nozzle_diameter: 0.4, extruders: 2)
    end
  end

  describe '#reported_specs' do
    let(:printer) { create(:printer, :prusalink) }
    let(:redis) { MockRedis.new }

    before do
      stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
      allow(Prusalink::Info).to receive(:get).and_return(Prusalink::Info.new(name: 'XL', nozzle_diameter: 0.6))
      allow(Prusalink::ServerVersion).to receive(:get).and_return(Prusalink::ServerVersion.new(firmware: '6.2.0'))
    end

    it 'is cached for 2 hours, and comes back from the cache with the same values' do
      first = printer.reported_specs

      expect(Printer.find(printer.id).reported_specs.serialize).to eq first.serialize
      expect(first).to have_attributes(name: 'XL', firmware: 'prusa_firmware', nozzle_diameter: 0.6)
      expect(Prusalink::Info).to have_received(:get).once
    end

    it 'is nil, without calling the server, while the printer is flagged disconnected' do
      PrinterApiCache.set_disconnected(printer.id)

      expect(printer.reported_specs).to be_nil
      expect(Prusalink::Info).not_to have_received(:get)
    end
  end

  describe '#fill_specs_from_server' do
    let(:printer) { create(:printer, :prusalink) }

    before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { MockRedis.new }) }

    it 'fills the blank specs with what the server reports, and saves when it read the server' do
      allow(printer).to receive(:reported_specs).and_return(PrinterBackends::ReportedSpecs.new(model: 'MK4'))

      expect(printer.fill_specs_from_server).to eq ['model']
      expect(printer.reload.model).to eq 'MK4'
      expect(printer.specs_filled_at).to be_within(1.second).of(Time.current)
    end

    it 'saves when it read the server, even with nothing to fill' do
      printer.update!(model: 'MK4')
      allow(printer).to receive(:reported_specs).and_return(PrinterBackends::ReportedSpecs.new(model: 'XL'))

      expect(printer.fill_specs_from_server).to eq []
      expect(printer.reload.specs_filled_at).to be_within(1.second).of(Time.current)
    end

    it 'is nil when the printer is unreachable, and leaves specs_filled_at nil' do
      allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::ConnectionError, 'timeout')

      expect(printer.fill_specs_from_server).to be_nil
      expect(printer.reload.specs_filled_at).to be_nil
    end

    it 'is nil, and logs why, when the server refuses the credentials' do
      allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::AuthenticationError, '[401]')
      allow(Rails.logger).to receive(:error)

      expect(printer.fill_specs_from_server).to be_nil
      expect(Rails.logger).to have_received(:error)
        .with("Could not read the specs of printer #{printer.id}: PrinterBackends::Unauthorized: [401]")
    end
  end
end
