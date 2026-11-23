# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query printer', type: :request do
  let(:query) { 'query printer($id: ID!) { printer(id: $id) { id name uri username } }' }
  let(:json) { response.parsed_body }

  it 'returns the printer with that id' do
    printer = create(:printer, name: 'Prusa MK4', backend: 'prusalink', uri: 'http://192.168.1.21', username: 'maker')

    post '/graphql', params: { query:, variables: { id: printer.id } }

    expect(json['errors']).to be_nil
    expect(json.dig('data', 'printer')).to eq(
      'id' => printer.id.to_s, 'name' => 'Prusa MK4', 'uri' => 'http://192.168.1.21', 'username' => 'maker'
    )
  end

  it 'returns whether it takes jobs from the global queue, even while the queue is off' do
    printer = create(:printer, takes_jobs: false)

    post '/graphql', params: { query: 'query($id: ID!) { printer(id: $id) { takesJobs } }',
                               variables: { id: printer.id } }

    expect(json['errors']).to be_nil
    expect(json.dig('data', 'printer')).to eq('takesJobs' => false)
  end

  it 'returns null when there is none, e.g. the printer was just removed' do
    post '/graphql', params: { query:, variables: { id: '0' } }

    expect(json['errors']).to be_nil
    expect(json['data']).to eq('printer' => nil)
  end
end
