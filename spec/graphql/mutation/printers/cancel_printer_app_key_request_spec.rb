# frozen_string_literal: true

require 'rails_helper'
require 'support/app_key_request_helpers'

RSpec.describe Mutations::Printers::CancelPrinterAppKeyRequest, type: :request do
  include AppKeyRequestHelpers

  let(:request) { create_request }
  let(:query) do
    <<~GQL
      mutation($id: ID!) {
        cancelPrinterAppKeyRequest(input: { id: $id }) {
          request { id address state approvalUrl printer { id } error }
          errors
        }
      }
    GQL
  end
  let(:data) { response.parsed_body['data']['cancelPrinterAppKeyRequest'] }
  let(:cancelled) do
    { 'id' => request.id, 'address' => '192.168.1.57', 'state' => 'CANCELLED',
      'approvalUrl' => request.approval_url, 'printer' => nil, 'error' => nil }
  end

  def cancel(id = request.id)
    post '/graphql', params: { query:, variables: { id: } }, as: :json
  end

  context 'while the request is waiting' do
    before do
      subscribe_to_request(request.id)
      cancel
      deliver_events
    end

    it 'returns the CANCELLED request' do
      expect(data).to eq('request' => cancelled, 'errors' => [])
    end

    it 'forgets it, so that the job stops, without telling OctoPrint' do
      expect(Printer::AppKeyRequest.find(request.id)).to be_nil
      expect(a_request(:any, //)).not_to have_been_made
    end

    it 'pushes CANCELLED to its subscribers' do
      expect(pushes).to eq([cancelled])
    end
  end

  it 'returns an error once the request is over or expired' do
    subscribe_to_request(request.id)
    cancel
    cancel
    deliver_events

    expect(data).to eq('request' => nil, 'errors' => ['This request is already over'])
    expect(pushes.size).to eq(1)
  end

  it 'returns an error for an unknown request' do
    cancel('3f9a1e64-0000-4000-8000-000000000000')

    expect(data).to eq('request' => nil, 'errors' => ['This request is already over'])
  end
end
