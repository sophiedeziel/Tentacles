# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query printerFits', type: :request do
  # The printers' snapshots, by printer id: Printer::Status.where reads them from here
  let(:statuses) { {} }
  let(:file) { create(:gcode_summary, :ready, :with_tools, materials: ['PLA']).item }
  let(:query) do
    <<~GQL
      query($fileId: ID!, $material: String, $colour: String) {
        printerFits(fileId: $fileId, material: $material, colour: $colour) {
          printer { name } result hardLimit reasons { code message }
        }
      }
    GQL
  end

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    allow(Printer::Status).to receive(:where) do |printer_id:|
      Array(printer_id).filter_map { |id| statuses[id] }
    end
  end

  def fits(**variables)
    post '/graphql', params: { query:, variables: { fileId: file.id, **variables }.to_json }
    body = response.parsed_body
    expect(body['errors']).to be_nil
    body.dig('data', 'printerFits')
  end

  # A printer with this filament loaded, in this state family (nil: no snapshot)
  def printer(name, family = Printer::StateFamily::Operational, material: 'PLA', colour: 'Black', **attributes)
    create(:printer, name:, **attributes).tap do |printer|
      create(:printer_loaded_filament, printer:, material:, colour:)
      next unless family

      statuses[printer.id] = Printer::Status.new(printer_id: printer.id, state_family: family,
                                                 state_text: family.serialize.capitalize)
    end
  end

  it 'is how every printer fits the file with the filament asked for, only the bed size a hard limit' do
    printer('Prusa MK4')
    printer('Voron 2.4', material: 'PETG', colour: 'Grey')
    printer('Prusa Mini', nil)
    printer('Mini Delta', bed_shape: 'circular', build_diameter: 110)

    expect(fits(material: 'PLA', colour: 'Black')).to eq [
      { 'printer' => { 'name' => 'Prusa MK4' }, 'result' => 'READY', 'hardLimit' => false,
        'reasons' => [{ 'code' => 'FILAMENT_MATCHES', 'message' => 'Loaded PLA Black matches' }] },
      { 'printer' => { 'name' => 'Voron 2.4' }, 'result' => 'AFTER_FILAMENT_CHANGE', 'hardLimit' => false,
        'reasons' => [{ 'code' => 'WRONG_MATERIAL', 'message' => 'Needs PLA Black. PETG is loaded here' }] },
      { 'printer' => { 'name' => 'Prusa Mini' }, 'result' => 'AFTER_RECONNECT', 'hardLimit' => false,
        'reasons' => [{ 'code' => 'OFFLINE', 'message' => 'Offline' }] },
      { 'printer' => { 'name' => 'Mini Delta' }, 'result' => 'CANNOT', 'hardLimit' => true,
        'reasons' => [{ 'code' => 'BED_TOO_SMALL',
                        'message' => 'Bed too small: needs 123.09 × 130 mm, has a 110 mm round bed' }] }
    ]
  end

  it "reads the G-code's material when none is asked for, and any colour" do
    printer('Voron 2.4', material: 'PLA', colour: 'Grey')

    expect(fits.first).to include('result' => 'READY')
    expect(fits(material: 'PETG').first).to include('result' => 'AFTER_FILAMENT_CHANGE')
  end

  it 'is null for an unknown file' do
    post '/graphql', params: { query:, variables: { fileId: file.id + 1 }.to_json }

    expect(response.parsed_body).to eq('data' => { 'printerFits' => nil })
  end

  it 'is null while the global queue is off' do
    allow(PrintQueue).to receive(:enabled?).and_return(false)
    post '/graphql', params: { query:, variables: { fileId: file.id }.to_json }

    expect(response.parsed_body).to eq('data' => { 'printerFits' => nil })
  end
end
