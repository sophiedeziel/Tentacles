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

  it 'takes the URL of the server' do
    stub_request(:post, 'http://octopi.local:5000/plugin/appkeys/request').to_return(created(app_token:))
    request_app_key('http://octopi.local:5000/')

    expect(data['request']).to include('address' => 'http://octopi.local:5000/',
                                       'approvalUrl' => 'http://octopi.local:5000/')
  end

  shared_examples 'a request OctoPrint could not take' do |message|
    it 'returns why, and neither keeps nor follows anything' do
      request_app_key

      expect(json['errors']).to be_nil
      expect(data).to eq('request' => nil, 'errors' => [message])
      expect(redis.keys).to be_empty
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

  it 'refuses a blank address without calling anything' do
    request_app_key(' ')

    expect(data).to eq('request' => nil, 'errors' => ['Enter the address of the OctoPrint server'])
    expect(a_request(:any, //)).not_to have_been_made
  end
end
