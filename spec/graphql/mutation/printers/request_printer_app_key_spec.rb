# frozen_string_literal: true

require 'rails_helper'
require 'support/app_key_request_helpers'

RSpec.describe Mutations::Printers::RequestPrinterAppKey, type: :request do
  include AppKeyRequestHelpers
  include ActiveJob::TestHelper

  let(:app_token) { AppKeyRequestHelpers::APP_TOKEN }
  let(:auth_dialog) { "http://192.168.1.57/plugin/appkeys/auth/#{app_token}" }
  let(:octoprint) { stub_request(:post, 'http://192.168.1.57/plugin/appkeys/request') }
  let(:query) do
    <<~GQL
      mutation($address: String!) {
        requestPrinterAppKey(input: { address: $address }) {
          request { id address state approvalUrl printer { id } error }
          errors
        }
      }
    GQL
  end
  let(:json) { response.parsed_body }
  let(:data) { json['data']['requestPrinterAppKey'] }

  def request_app_key(address = '192.168.1.57')
    post '/graphql', params: { query:, variables: { address: } }, as: :json
  end

  # What the last networkPrinters scan found
  before { redis.set(:printers_ips, %w[192.168.1.20 192.168.1.57].to_json) }

  def created(body)
    { status: 201, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  context 'when OctoPrint takes the request' do
    before do
      octoprint.to_return(created(app_token:, auth_dialog:))
      request_app_key
    end

    let(:id) { data.dig('request', 'id') }

    it "asks OctoPrint for a key for Tentacles, and returns the WAITING request with OctoPrint's dialog" do
      expect(a_request(:post, 'http://192.168.1.57/plugin/appkeys/request').with(body: { app: 'Tentacles' }))
        .to have_been_made.once
      expect(json['errors']).to be_nil
      expect(data).to eq('request' => { 'id' => id, 'address' => '192.168.1.57', 'state' => 'WAITING',
                                        'approvalUrl' => auth_dialog, 'printer' => nil, 'error' => nil },
                         'errors' => [])
    end

    it 'keeps the app token in Redis for 15 minutes, under the request id' do
      expect(id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      expect(PrinterAppKeyRequest.find(id)).to have_attributes(address: '192.168.1.57', app_token:)
      expect(redis.ttl("printer_app_key_request_#{id}")).to eq(15.minutes.to_i)
    end

    it 'starts polling right away' do
      expect(OctoprintAppKeyPollJob).to have_been_enqueued.with(id).exactly(:once)
      expect(enqueued_jobs.last).not_to have_key(:at)
    end
  end

  it "returns OctoPrint's address to open when OctoPrint reports no dialog (before 1.8)" do
    octoprint.to_return(created(app_token:))
    request_app_key(' 192.168.1.57 ')

    expect(data['request']).to include('address' => '192.168.1.57', 'approvalUrl' => 'http://192.168.1.57/')
  end

  it 'calls an IPv6 address the scan found in brackets' do
    redis.set(:printers_ips, ['fd00::57'].to_json)
    stub_request(:post, 'http://[fd00::57]/plugin/appkeys/request').to_return(created(app_token:))
    request_app_key('FD00:0:0:0:0:0:0:57')

    expect(data['request']).to include('address' => 'fd00::57', 'approvalUrl' => 'http://[fd00::57]/')
  end

  # Only the addresses the scan found are called: the server never calls an address a client made up (SSRF)
  shared_examples 'an address that is refused without calling anything' do |address, message|
    it "refuses #{address.inspect}" do
      request_app_key(address)

      expect(json['errors']).to be_nil
      expect(data).to eq('request' => nil, 'errors' => [message])
      expect(a_request(:any, //)).not_to have_been_made
      expect(OctoprintAppKeyPollJob).not_to have_been_enqueued
    end
  end

  not_an_ip = 'Enter the IP address of an OctoPrint server found by the network scan, e.g. 192.168.1.57'
  it_behaves_like 'an address that is refused without calling anything', ' ',
                  'Enter the address of the OctoPrint server'
  it_behaves_like 'an address that is refused without calling anything', 'octopi.local', not_an_ip
  it_behaves_like 'an address that is refused without calling anything', 'http://192.168.1.57/', not_an_ip
  it_behaves_like 'an address that is refused without calling anything', '192.168.1.57:5000', not_an_ip
  it_behaves_like 'an address that is refused without calling anything', '192.168.1.0/24', not_an_ip
  it_behaves_like 'an address that is refused without calling anything', 'fe80::1%en0', not_an_ip
  it_behaves_like 'an address that is refused without calling anything', '169.254.169.254',
                  'The network scan did not find OctoPrint at 169.254.169.254. Scan the network again.'

  it 'refuses every address before the first scan' do
    redis.del(:printers_ips)
    request_app_key

    expect(data['errors']).to eq ['The network scan did not find OctoPrint at 192.168.1.57. Scan the network again.']
    expect(a_request(:any, //)).not_to have_been_made
  end

  shared_examples 'a request OctoPrint could not take' do |message|
    it 'returns why, and neither keeps nor follows anything' do
      request_app_key

      expect(json['errors']).to be_nil
      expect(data).to eq('request' => nil, 'errors' => [message])
      expect(redis.keys).to eq ['printers_ips']
      expect(OctoprintAppKeyPollJob).not_to have_been_enqueued
    end
  end

  context 'when OctoPrint is unreachable' do
    before { octoprint.to_timeout }

    it_behaves_like 'a request OctoPrint could not take', 'Could not reach OctoPrint at http://192.168.1.57/'

    it 'logs it' do
      request_app_key

      expect(log.string).to include('[requestPrinterAppKey] Could not ask "http://192.168.1.57/" for an app key: ' \
                                    'PrinterBackends::Unreachable')
    end
  end

  context 'when OctoPrint got too many requests (3 a minute)' do
    before { octoprint.to_return(status: 429, body: '{"error": "Too many requests"}') }

    it_behaves_like 'a request OctoPrint could not take',
                    'OctoPrint at http://192.168.1.57/ got too many requests. Try again in a minute.'
  end

  context 'when the server has no Application Keys plugin' do
    before { octoprint.to_return(status: 404) }

    it_behaves_like 'a request OctoPrint could not take',
                    'OctoPrint at http://192.168.1.57/ refused the request (HTTP 404). Is its Application Keys ' \
                    'plugin enabled?'
  end

  context 'when the server is not OctoPrint' do
    before { octoprint.to_return(status: 201, body: '<html></html>') }

    it_behaves_like 'a request OctoPrint could not take', 'http://192.168.1.57/ does not answer like OctoPrint'
  end
end
