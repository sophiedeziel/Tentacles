# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::PrinterSpecs, type: :request do
  let(:query) do
    <<~GQL
      query printer($id: ID!) {
        printer(id: $id) {
          favorite
          specs {
            brand model firmware firmwareDisplayName firmwareVersion
            buildVolume {
              __typename
              ... on RectangularBuildVolume { x y z }
              ... on CircularBuildVolume { diameter height }
            }
            extruders nozzleDiameter maxHotendTemp maxBedTemp heatedBed heatedChamber webcam materials
          }
        }
      }
    GQL
  end
  def json = response.parsed_body
  def specs = json.dig('data', 'printer', 'specs')

  def query_printer(printer)
    post '/graphql', params: { query:, variables: { id: printer.id } }
    expect(json['errors']).to be_nil
  end

  it "returns a printer's saved specs, without contacting it" do
    printer = create(:printer, favorite: true, brand: 'Prusa Research', model: 'MK4', firmware: 'prusa_firmware',
                               firmware_version: '6.2.0', bed_shape: 'rectangular', build_volume_x: 250,
                               build_volume_y: 210, build_volume_z: 220, extruders: 1, nozzle_diameter: 0.6,
                               max_hotend_temp: 290, max_bed_temp: 120, heated_bed: true, heated_chamber: false,
                               webcam: false, materials: %w[PLA PETG])
    expect(Octoprint::Client).not_to receive(:new)

    query_printer(printer)

    expect(json.dig('data', 'printer', 'favorite')).to be true
    expect(specs).to eq(
      'brand' => 'Prusa Research', 'model' => 'MK4', 'firmware' => 'PRUSA_FIRMWARE',
      'firmwareDisplayName' => 'prusa_firmware', 'firmwareVersion' => '6.2.0',
      'buildVolume' => { '__typename' => 'RectangularBuildVolume', 'x' => 250.0, 'y' => 210.0, 'z' => 220.0 },
      'extruders' => 1, 'nozzleDiameter' => 0.6, 'maxHotendTemp' => 290, 'maxBedTemp' => 120,
      'heatedBed' => true, 'heatedChamber' => false, 'webcam' => false, 'materials' => %w[PLA PETG]
    )
  end

  it 'returns null for every spec that is not set, and no materials' do
    query_printer(create(:printer))

    expect(json.dig('data', 'printer', 'favorite')).to be false
    expect(specs.except('materials').values).to all(be_nil)
    expect(specs['materials']).to eq []
  end

  it 'returns no materials for a printer saved before the column existed' do
    printer = create(:printer)
    printer.update_column(:materials, nil) # rubocop:disable Rails/SkipsModelValidations

    query_printer(printer)

    expect(specs['materials']).to eq []
  end

  describe 'firmware' do
    it 'maps each known firmware to its value' do
      values = Printer::Specs::KNOWN_FIRMWARES.map do |firmware|
        query_printer(create(:printer, firmware:))
        specs.values_at('firmware', 'firmwareDisplayName')
      end

      expect(values).to eq [%w[MARLIN marlin], %w[KLIPPER klipper], %w[PRUSA_FIRMWARE prusa_firmware],
                            %w[REPRAPFIRMWARE reprapfirmware]]
    end

    it 'returns OTHER and the saved text for a firmware Tentacles does not know' do
      query_printer(create(:printer, firmware: 'Smoothieware'))

      expect(specs).to include('firmware' => 'OTHER', 'firmwareDisplayName' => 'Smoothieware')
    end
  end

  describe 'buildVolume' do
    let(:volume) { specs['buildVolume'] }

    it 'is rectangular when the bed shape is not set and X, Y and Z are' do
      query_printer(create(:printer, build_volume_x: 180, build_volume_y: 180, build_volume_z: 180.5))

      expect(volume).to eq('__typename' => 'RectangularBuildVolume', 'x' => 180.0, 'y' => 180.0, 'z' => 180.5)
    end

    it 'is circular, with the diameter and the height, for a circular bed' do
      query_printer(create(:printer, bed_shape: 'circular', build_diameter: 230, build_volume_z: 300))

      expect(volume).to eq('__typename' => 'CircularBuildVolume', 'diameter' => 230.0, 'height' => 300.0)
    end

    it 'is null while a dimension of a rectangular bed is missing' do
      query_printer(create(:printer, bed_shape: 'rectangular', build_volume_x: 250, build_volume_y: 210,
                                     build_diameter: 230))

      expect(volume).to be_nil
    end

    it 'is null while a dimension of a circular bed is missing' do
      query_printer(create(:printer, bed_shape: 'circular', build_volume_x: 250, build_volume_y: 210,
                                     build_volume_z: 300))

      expect(volume).to be_nil
    end
  end

  it 'can be broadcast by printerStatusChanged' do
    subscription = 'subscription { printerStatusChanged { id favorite specs { brand materials buildVolume { ' \
                   '... on RectangularBuildVolume { x y z } ... on CircularBuildVolume { diameter height } } } } }'

    expect(TentaclesSchema.subscriptions.broadcastable?(subscription)).to be(true)
  end
end
