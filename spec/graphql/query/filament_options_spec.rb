# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query filamentMaterials and filamentColours', type: :request do
  let(:json) { response.parsed_body }

  def load_filament(colour, material: 'PLA', updated_at: Time.current)
    create(:printer_loaded_filament, printer: create(:printer), material:, colour:, updated_at:)
  end

  it 'lists the materials of Filament::MATERIALS' do
    post '/graphql', params: { query: 'query { filamentMaterials }' }

    expect(json['errors']).to be_nil
    expect(json['data']['filamentMaterials']).to eq(%w[PLA PETG ABS ASA TPU PC PA PVA HIPS])
  end

  describe 'filamentColours' do
    let(:colours) { json['data']['filamentColours'] }

    before { allow(TentaclesSchema.subscriptions).to receive(:trigger) }

    def query_colours
      post '/graphql', params: { query: 'query { filamentColours }' }
    end

    it 'lists the defaults first, then the colours in use, alphabetical' do
      load_filament('Silk Gold')
      load_filament('galaxy black')
      load_filament('Army green', material: 'PETG')

      query_colours

      expect(colours).to eq(Filament::DEFAULT_COLOURS + ['Army green', 'galaxy black', 'Silk Gold'])
    end
  end
end
