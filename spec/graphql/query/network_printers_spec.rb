# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Resolvers::NetworkPrinters, type: :request do
  let(:scanner) { instance_double(PrinterScanner, call: ['192.168.1.57', '192.168.1.60']) }
  let!(:saved) { create(:printer, name: 'Prusa MK4', uri: 'http://192.168.1.57:80/') }

  before { allow(PrinterScanner).to receive(:new).and_return(scanner) }

  def json = response.parsed_body

  def query(graphql, variables = {})
    post '/graphql', params: { query: graphql, variables: }, as: :json
    expect(json['errors']).to be_nil
    json['data']
  end

  describe 'networkPrinters' do
    let(:graphql) do
      'query($refresh: Boolean) { networkPrinters(refresh: $refresh) { address url printer { id name } } }'
    end

    it 'returns every OctoPrint found, with the saved printer of the same host, null otherwise' do
      expect(query(graphql)['networkPrinters']).to eq(
        [
          { 'address' => '192.168.1.57', 'url' => 'http://192.168.1.57/',
            'printer' => { 'id' => saved.id.to_s, 'name' => 'Prusa MK4' } },
          { 'address' => '192.168.1.60', 'url' => 'http://192.168.1.60/', 'printer' => nil }
        ]
      )
    end

    it 'picks the first printer added when several have that host' do
      create(:printer, name: 'Second', uri: 'http://192.168.1.57:5000/')

      expect(query(graphql)['networkPrinters'].first['printer']['name']).to eq('Prusa MK4')
    end

    it 'ignores saved printers with an invalid URL' do
      saved.update!(uri: 'http://bad host/')

      expect(query(graphql)['networkPrinters'].pluck('printer')).to eq([nil, nil])
    end

    it 'reuses the cached scan by default' do
      query(graphql)
      query(graphql, { refresh: nil })

      expect(scanner).to have_received(:call).with(refresh: false).twice
    end

    it 'scans again with refresh: true' do
      query(graphql, { refresh: true })

      expect(scanner).to have_received(:call).with(refresh: true)
    end
  end
end
