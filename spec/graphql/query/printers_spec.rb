# frozen_string_literal: true

require 'rails_helper'
require 'support/unreadable_secret'

RSpec.describe 'Query printers', type: :request do
  include UnreadableSecret

  let(:redis) { MockRedis.new }
  let!(:readable) { create(:printer, name: 'Readable') }
  let!(:unreadable) { make_secret_unreadable(create(:printer, name: 'Unreadable')) }
  let(:query) { 'query { printers { id name octoprintUri octoprintVersion jobStatus } }' }
  let(:json) { response.parsed_body }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(Octoprint::ServerVersion).to receive(:get)
      .and_return(Octoprint::ServerVersion.new(api: '0.1', server: '1.11.2', text: 'OctoPrint 1.11.2'))
    allow(Octoprint::Job).to receive(:get).and_return(Octoprint::Job.deserialize({ state: 'Operational', job: {} }))
  end

  it "still lists every printer when one printer's secret cannot be decrypted" do
    post '/graphql', params: { query: }

    expect(json['errors']).to be_nil
    expect(json['data']['printers']).to contain_exactly(
      { 'id' => readable.id.to_s, 'name' => 'Readable', 'octoprintUri' => 'http://10.0.1.165/',
        'octoprintVersion' => 'OctoPrint 1.11.2', 'jobStatus' => 'Operational' },
      { 'id' => unreadable.id.to_s, 'name' => 'Unreadable', 'octoprintUri' => 'http://10.0.1.165/',
        'octoprintVersion' => 'Unavailable', 'jobStatus' => nil }
    )
  end

  describe 'the backend fields' do
    let!(:prusalink) { create(:printer, :prusalink, name: 'Prusa MK4') }
    let(:query) do
      'query { printers { name backend uri username version octoprintUri octoprintVersion } }'
    end
    let(:printers) { json['data']['printers'].index_by { |printer| printer['name'] } }

    before do
      allow(Prusalink::ServerVersion).to receive(:get)
        .and_return(Prusalink::ServerVersion.deserialize({ version: '2.1.2', firmware: '6.1.3' }))
      post '/graphql', params: { query: }
    end

    it "returns a PrusaLink printer's backend, URL, username and version" do
      expect(json['errors']).to be_nil
      expect(printers['Prusa MK4']).to include(
        'backend' => 'PRUSALINK', 'uri' => 'http://prusa-mk4.local', 'username' => 'maker',
        'version' => 'PrusaLink 2.1.2 (firmware 6.1.3)', 'octoprintUri' => 'http://prusa-mk4.local',
        'octoprintVersion' => 'PrusaLink 2.1.2 (firmware 6.1.3)'
      )
    end

    it 'never returns a secret' do
      expect(response.body).not_to include(prusalink.secret)
      expect(response.body).not_to include(readable.secret)
      expect(TentaclesSchema.get_type('Printer').fields.keys).not_to include('octoprintKey', 'secret')
    end

    it "returns an OctoPrint printer's backend and version" do
      expect(printers['Readable']).to include(
        'backend' => 'OCTOPRINT', 'uri' => 'http://10.0.1.165/', 'username' => nil,
        'version' => 'OctoPrint 1.11.2'
      )
    end

    it "returns 'Unavailable' when the version can't be read" do
      expect(printers['Unreadable']).to include('backend' => 'OCTOPRINT', 'version' => 'Unavailable',
                                                'octoprintVersion' => 'Unavailable')
    end
  end
end
