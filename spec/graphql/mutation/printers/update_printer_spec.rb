# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Printers::UpdatePrinter, type: :request do
  let(:redis) { MockRedis.new }
  let(:printer) do
    create(:printer, :prusalink, name: 'Prusa MK4', brand: 'Prusa', model: 'MK4', firmware: 'prusa_firmware',
                                 extruders: 1, materials: %w[PLA PETG], bed_shape: 'rectangular',
                                 build_volume_x: 250, build_volume_y: 210, build_volume_z: 220)
  end
  let(:input) { { id: printer.id } }
  let(:data) { response.parsed_body.dig('data', 'updatePrinter') }
  let(:query) do
    <<~GQL
      mutation updatePrinter($input: UpdatePrinterInput!) {
        updatePrinter(input: $input) {
          printer {
            id name uri username
            specs {
              brand model firmware firmwareDisplayName extruders materials
              buildVolume {
                ... on RectangularBuildVolume { x y z }
                ... on CircularBuildVolume { diameter height }
              }
            }
          }
          errors
        }
      }
    GQL
  end

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  def update_printer
    post '/graphql', params: { query:, variables: { input: } }, as: :json
  end

  def build_volume_columns
    printer.reload.slice(:bed_shape, :build_volume_x, :build_volume_y, :build_volume_z, :build_diameter)
           .transform_values { |value| value.is_a?(BigDecimal) ? value.to_f : value }
  end

  it 'writes the fields sent and leaves the omitted ones as they are' do
    input.merge!(name: 'Workshop MK4', specs: { model: 'MK4S', extruders: 2 })

    update_printer

    expect(response.parsed_body['errors']).to be_nil
    expect(data['errors']).to eq([])
    expect(data['printer']).to include('name' => 'Workshop MK4', 'uri' => 'http://prusa-mk4.local',
                                       'username' => 'maker')
    expect(data['printer']['specs']).to include('brand' => 'Prusa', 'model' => 'MK4S', 'extruders' => 2,
                                                'materials' => %w[PLA PETG],
                                                'buildVolume' => { 'x' => 250.0, 'y' => 210.0, 'z' => 220.0 })
  end

  it 'clears the fields sent as null' do
    input.merge!(username: nil, specs: { brand: nil, extruders: nil, materials: nil })

    update_printer

    expect(data['errors']).to eq([])
    expect(printer.reload).to have_attributes(username: nil, brand: nil, extruders: nil, materials: [],
                                              model: 'MK4')
  end

  it 'changes nothing for null specs' do
    input.merge!(specs: nil)

    update_printer

    expect(data['errors']).to eq([])
    expect(printer.reload).to have_attributes(brand: 'Prusa', model: 'MK4', extruders: 1)
  end

  it 'saves any firmware as free text' do
    input.merge!(specs: { firmware: ' Smoothieware ' })

    update_printer

    expect(data['printer']['specs']).to include('firmware' => 'OTHER', 'firmwareDisplayName' => 'Smoothieware')
  end

  describe 'secret' do
    it 'replaces the saved secret with the one sent' do
      input.merge!(secret: 'new-password')

      update_printer

      expect(data['errors']).to eq([])
      expect(printer.reload.secret).to eq('new-password')
    end

    [nil, ''].each do |blank|
      it "keeps the saved secret for #{blank.inspect}" do
        input.merge!(secret: blank, name: 'Renamed')

        update_printer

        expect(data['errors']).to eq([])
        expect(printer.reload).to have_attributes(name: 'Renamed', secret: 'printer-password')
      end
    end

    it 'is never returned' do
      update_printer

      expect(response.body).not_to include('printer-password')
    end
  end

  describe 'buildVolume' do
    it 'sets a rectangular bed and clears the diameter' do
      printer.update!(bed_shape: 'circular', build_diameter: 180, build_volume_x: nil, build_volume_y: nil)
      input.merge!(specs: { buildVolume: { rectangular: { x: 300, y: 300, z: 400 } } })

      update_printer

      expect(data['printer']['specs']['buildVolume']).to eq('x' => 300.0, 'y' => 300.0, 'z' => 400.0)
      expect(build_volume_columns).to eq('bed_shape' => 'rectangular', 'build_volume_x' => 300.0,
                                         'build_volume_y' => 300.0, 'build_volume_z' => 400.0,
                                         'build_diameter' => nil)
    end

    it 'sets a circular bed and clears X and Y' do
      input.merge!(specs: { buildVolume: { circular: { diameter: 180, height: 300 } } })

      update_printer

      expect(data['printer']['specs']['buildVolume']).to eq('diameter' => 180.0, 'height' => 300.0)
      expect(build_volume_columns).to eq('bed_shape' => 'circular', 'build_volume_x' => nil, 'build_volume_y' => nil,
                                         'build_volume_z' => 300.0, 'build_diameter' => 180.0)
    end

    it 'clears the bed shape and every dimension for null' do
      input.merge!(specs: { buildVolume: nil })

      update_printer

      expect(data['printer']['specs']['buildVolume']).to be_nil
      expect(build_volume_columns.values).to all(be_nil)
    end

    it 'refuses both shapes at once' do
      input.merge!(specs: { buildVolume: { rectangular: { x: 1, y: 1, z: 1 }, circular: { diameter: 1, height: 1 } } })

      update_printer

      expect(response.parsed_body['errors'].first['message']).to match(/requires exactly one argument/)
      expect(build_volume_columns['build_volume_x']).to eq(250.0)
    end
  end

  describe 'validation errors' do
    it 'returns them with the printer as saved' do
      input.merge!(name: '', specs: { extruders: 0, buildVolume: { circular: { diameter: -1, height: 300 } } })

      update_printer

      expect(data['errors']).to contain_exactly("Name can't be blank", 'Extruders must be greater than or equal to 1',
                                                'Build diameter must be greater than 0')
      expect(data['printer']).to include('name' => 'Prusa MK4')
      expect(data['printer']['specs']).to include('extruders' => 1,
                                                  'buildVolume' => { 'x' => 250.0, 'y' => 210.0, 'z' => 220.0 })
    end
  end

  it 'returns an error for an unknown printer' do
    input[:id] = printer.id + 1

    update_printer

    expect(data).to eq('printer' => nil, 'errors' => ['Printer not found'])
  end

  describe 'uri' do
    before do
      PrinterApiCache.set_disconnected(printer.id)
      redis.set("printer_api_#{printer.id}_version", 'cached')
    end

    it 'forgets the disconnected flag and the cached answers when it changes' do
      input.merge!(uri: 'http://192.168.1.60')

      update_printer

      expect(printer.reload.uri).to eq('http://192.168.1.60')
      expect(PrinterApiCache.disconnected?(printer.id)).to be false
      expect(redis.get("printer_api_#{printer.id}_version")).to be_nil
    end

    it 'keeps them when it does not change' do
      input.merge!(uri: 'http://prusa-mk4.local', name: 'Renamed')

      update_printer

      expect(PrinterApiCache.disconnected?(printer.id)).to be true
      expect(redis.get("printer_api_#{printer.id}_version")).to eq('cached')
    end

    it 'keeps them when the printer is invalid' do
      input.merge!(uri: 'http://192.168.1.60', name: '')

      update_printer

      expect(printer.reload.uri).to eq('http://prusa-mk4.local')
      expect(PrinterApiCache.disconnected?(printer.id)).to be true
    end
  end
end
