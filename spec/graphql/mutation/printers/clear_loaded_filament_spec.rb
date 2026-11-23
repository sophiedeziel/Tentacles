# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Printers::ClearLoadedFilament, type: :request do
  let(:printer) { create(:printer) }
  let(:input) { { printerId: printer.id } }
  let(:data) { response.parsed_body.dig('data', 'clearLoadedFilament') }
  let(:query) do
    <<~GQL
      mutation clearLoadedFilament($input: ClearLoadedFilamentInput!) {
        clearLoadedFilament(input: $input) {
          printer { id loadedFilaments { slot material colour } }
          errors { field message }
        }
      }
    GQL
  end

  before { allow(TentaclesSchema.subscriptions).to receive(:trigger) }

  def clear_loaded_filament
    post '/graphql', params: { query:, variables: { input: } }, as: :json
  end

  context 'when a filament is loaded' do
    before { create(:printer_loaded_filament, printer:, material: 'PLA', colour: 'Black') }

    it 'removes it from slot 1 by default and returns the printer without it' do
      clear_loaded_filament

      expect(response.parsed_body['errors']).to be_nil
      expect(data).to eq('printer' => { 'id' => printer.id.to_s, 'loadedFilaments' => [] }, 'errors' => [])
      expect(printer.reload.filament_set?).to be false
    end

    it 'leaves it when another slot is cleared' do
      input[:slot] = 2

      clear_loaded_filament

      expect(data['errors']).to eq([])
      expect(data['printer']['loadedFilaments']).to eq([{ 'slot' => 1, 'material' => 'PLA', 'colour' => 'Black' }])
      expect(TentaclesSchema.subscriptions).not_to have_received(:trigger)
    end
  end

  it 'returns one error and no printer for an unknown printer' do
    input[:printerId] = printer.id + 1

    clear_loaded_filament

    expect(response.parsed_body['errors']).to be_nil
    expect(data).to eq('printer' => nil, 'errors' => [{ 'field' => nil, 'message' => 'Printer not found' }])
  end
end
