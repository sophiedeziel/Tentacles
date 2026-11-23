# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Printers::SetLoadedFilament, type: :request do
  let(:printer) { create(:printer) }
  let(:input) { { printerId: printer.id, material: 'petg', colour: 'Galaxy Black' } }
  let(:data) { response.parsed_body.dig('data', 'setLoadedFilament') }
  let(:query) do
    <<~GQL
      mutation setLoadedFilament($input: SetLoadedFilamentInput!) {
        setLoadedFilament(input: $input) {
          printer { id loadedFilaments { slot material colour updatedAt } }
          errors { field message }
        }
      }
    GQL
  end

  before { allow(TentaclesSchema.subscriptions).to receive(:trigger) }

  def set_loaded_filament
    post '/graphql', params: { query:, variables: { input: } }, as: :json
  end

  def loaded_filaments
    printer.loaded_filaments.reload.map { |filament| filament.slice(:slot, :material, :colour, :colour_key) }
  end

  it 'returns the printer with the new filament, in slot 1 by default' do
    set_loaded_filament

    expect(response.parsed_body['errors']).to be_nil
    expect(data['errors']).to eq([])
    expect(data['printer']['id']).to eq(printer.id.to_s)
    expect(data['printer']['loadedFilaments']).to contain_exactly(
      a_hash_including('slot' => 1, 'material' => 'PETG', 'colour' => 'Galaxy Black', 'updatedAt' => be_present)
    )
    expect(loaded_filaments).to eq(
      [{ 'slot' => 1, 'material' => 'PETG', 'colour' => 'Galaxy Black', 'colour_key' => 'galaxy black' }]
    )
  end

  it 'replaces the filament already loaded' do
    create(:printer_loaded_filament, printer:, material: 'PLA', colour: 'White')

    set_loaded_filament

    expect(data['printer']['loadedFilaments']).to contain_exactly(
      a_hash_including('slot' => 1, 'material' => 'PETG', 'colour' => 'Galaxy Black')
    )
    expect(loaded_filaments.size).to eq 1
  end

  it 'sets slot 1 when the slot is null' do
    input[:slot] = nil

    set_loaded_filament

    expect(data['errors']).to eq([])
    expect(loaded_filaments.pluck('slot')).to eq [1]
  end

  it 'triggers printerStatusChanged for the printer once' do
    set_loaded_filament

    expect(TentaclesSchema.subscriptions).to have_received(:trigger).once
    expect(TentaclesSchema.subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer)
  end

  describe 'invalid input' do
    let!(:loaded) { create(:printer_loaded_filament, printer:, material: 'PLA', colour: 'White') }

    shared_examples 'a refused filament' do |field, message|
      it "returns a user error on #{field.inspect}, changes nothing and pushes nothing" do
        expect { set_loaded_filament }.not_to(change { loaded.reload.attributes })

        expect(response.parsed_body['errors']).to be_nil
        expect(data['errors']).to eq([{ 'field' => field, 'message' => message }])
        expect(data['printer']['id']).to eq(printer.id.to_s)
        expect(data['printer']['loadedFilaments']).to match(
          [a_hash_including('slot' => 1, 'material' => 'PLA', 'colour' => 'White')]
        )
        expect(Printer::LoadedFilament.count).to eq 1
        expect(TentaclesSchema.subscriptions).not_to have_received(:trigger)
      end
    end

    context 'with a material outside the list' do
      before { input[:material] = 'Wood' }

      it_behaves_like 'a refused filament', 'material', 'Material is not included in the list'
    end

    context 'with a blank colour' do
      before { input[:colour] = '  ' }

      it_behaves_like 'a refused filament', 'colour', "Colour can't be blank"
    end

    context 'with a slot above filamentSlots' do
      before { input[:slot] = 2 }

      it_behaves_like 'a refused filament', 'slot', 'Slot must be less than or equal to 1'
    end
  end

  it 'returns one error and no printer for an unknown printer' do
    input[:printerId] = printer.id + 1

    set_loaded_filament

    expect(response.parsed_body['errors']).to be_nil
    expect(data).to eq('printer' => nil, 'errors' => [{ 'field' => nil, 'message' => 'Printer not found' }])
    expect(Printer::LoadedFilament.count).to eq 0
  end
end
