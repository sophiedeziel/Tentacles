# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query octoprintName', type: :request do
  let(:redis) { MockRedis.new }
  let(:variables) { { octoprintUri: 'http://192.168.0.15', octoprintKey: '12345678' } }
  let(:query) do
    <<~GQL
      query octoprintName($octoprintUri: URL!, $octoprintKey: String!) {
        octoprintName(octoprintUri: $octoprintUri, octoprintKey: $octoprintKey)
      }
    GQL
  end
  let(:json) { response.parsed_body }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(Octoprint::ServerVersion).to receive(:get)
      .and_return(Octoprint::ServerVersion.new(api: '0.1', server: '1.11.2', text: 'OctoPrint 1.11.2'))
  end

  def connection(printer_profiles)
    Octoprint::Connection.new(current: { state: 'Operational' }, options: { printer_profiles: })
  end

  it "returns the default printer profile's name" do
    allow(Octoprint::Connection).to receive(:get).and_return(
      connection([{ id: 'other', name: 'Other' }, { id: '_default', name: 'Ender 3' }])
    )

    post '/graphql', params: { query:, variables: }

    expect(json['errors']).to be_nil
    expect(json['data']['octoprintName']).to eq('Ender 3')
  end

  it 'returns nil when there is no default profile' do
    allow(Octoprint::Connection).to receive(:get).and_return(connection([{ id: 'other', name: 'Other' }]))

    post '/graphql', params: { query:, variables: }

    expect(json['errors']).to be_nil
    expect(json['data']['octoprintName']).to be_nil
  end

  {
    Octoprint::Exceptions::ConnectionError.new('Failed to open TCP connection') => PrinterBackends::Unreachable,
    Octoprint::Exceptions::TimeoutError.new('execution expired') => PrinterBackends::Unreachable,
    Octoprint::Exceptions::AuthenticationError.new('Invalid API key') => PrinterBackends::Unauthorized,
    JSON::ParserError.new("unexpected character: '<html>'") => JSON::ParserError, # A server that isn't OctoPrint
    KeyError.new('key not found: :error') => KeyError
  }.each do |error, logged_class|
    it "returns nil without an error when OctoPrint raises #{error.class.name}" do
      allow(Octoprint::Connection).to receive(:get).and_raise(error)
      allow(Rails.logger).to receive(:warn).and_call_original

      post '/graphql', params: { query:, variables: }

      expect(response).to have_http_status(:ok)
      expect(json['errors']).to be_nil
      expect(json['data']['octoprintName']).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/#{logged_class.name}/)
    end
  end
end
