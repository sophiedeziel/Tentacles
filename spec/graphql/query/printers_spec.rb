# frozen_string_literal: true

require 'rails_helper'
require 'support/unreadable_secret'

RSpec.describe 'Query printers', type: :request do
  include UnreadableSecret

  let(:redis) { MockRedis.new }
  let!(:readable) { create(:printer, name: 'Readable') }
  let!(:unreadable) { make_secret_unreadable(create(:printer, name: 'Unreadable')) }
  let(:query) { 'query { printers { id name octoprintUri octoprintKey octoprintVersion jobStatus } }' }
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
        'octoprintKey' => readable.secret, 'octoprintVersion' => 'OctoPrint 1.11.2', 'jobStatus' => 'Operational' },
      { 'id' => unreadable.id.to_s, 'name' => 'Unreadable', 'octoprintUri' => 'http://10.0.1.165/',
        'octoprintKey' => nil, 'octoprintVersion' => 'Unavailable', 'jobStatus' => nil }
    )
  end
end
