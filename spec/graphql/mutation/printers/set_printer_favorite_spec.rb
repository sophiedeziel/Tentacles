# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Printers::SetPrinterFavorite, type: :request do
  let(:printer) { create(:printer) }
  let(:data) { response.parsed_body.dig('data', 'setPrinterFavorite') }
  let(:query) do
    <<~GQL
      mutation setPrinterFavorite($input: SetPrinterFavoriteInput!) {
        setPrinterFavorite(input: $input) { printer { id favorite } errors }
      }
    GQL
  end

  def set_favorite(id, favorite)
    post '/graphql', params: { query:, variables: { input: { id:, favorite: } } }, as: :json
  end

  it 'marks a printer as a favorite' do
    set_favorite(printer.id, true)

    expect(response.parsed_body['errors']).to be_nil
    expect(data).to eq('printer' => { 'id' => printer.id.to_s, 'favorite' => true }, 'errors' => [])
    expect(printer.reload.favorite).to be true
  end

  it 'unmarks a favorite' do
    printer.update!(favorite: true)

    set_favorite(printer.id, false)

    expect(data).to eq('printer' => { 'id' => printer.id.to_s, 'favorite' => false }, 'errors' => [])
    expect(printer.reload.favorite).to be false
  end

  it 'returns an error for an unknown printer' do
    set_favorite(printer.id + 1, true)

    expect(data).to eq('printer' => nil, 'errors' => ['Printer not found'])
  end

  it 'returns the saved printer and the errors when the printer is invalid' do
    printer.update_column(:bed_shape, 'hexagonal') # rubocop:disable Rails/SkipsModelValidations

    set_favorite(printer.id, true)

    expect(data).to eq('printer' => { 'id' => printer.id.to_s, 'favorite' => false },
                       'errors' => ['Bed shape is not included in the list'])
    expect(printer.reload.favorite).to be false
  end
end
