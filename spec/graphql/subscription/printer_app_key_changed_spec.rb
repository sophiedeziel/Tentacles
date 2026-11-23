# frozen_string_literal: true

require 'rails_helper'
require 'support/app_key_request_helpers'

RSpec.describe Subscriptions::PrinterAppKeyChanged do
  include AppKeyRequestHelpers

  let(:request) { create_request }
  let(:other_request) { create_request(app_token: 'OTHER-APP-TOKEN') }

  it 'sends nothing on subscribe' do
    result = subscribe_to_request(request.id)

    expect(result['errors']).to be_nil
    expect(result['data']).to be_blank
    expect(result.context[:subscription_id]).to be_present
  end

  it 'pushes every change of the request to its subscribers only' do
    first = subscribe_to_request(request.id).context[:subscription_id]
    second = subscribe_to_request(request.id).context[:subscription_id]
    other = subscribe_to_request(other_request.id).context[:subscription_id]

    request.push('failed', error: 'Could not reach OctoPrint at http://192.168.1.57/')
    deliver_events

    expected = { 'id' => request.id, 'address' => '192.168.1.57', 'state' => 'FAILED',
                 'approvalUrl' => request.approval_url, 'printer' => nil,
                 'error' => 'Could not reach OctoPrint at http://192.168.1.57/' }
    expect(pushes(first)).to eq([expected])
    expect(pushes(second)).to eq([expected])
    expect(pushes(other)).to be_empty
  end

  it 'pushes the printer that was added' do
    printer = create(:printer, name: 'Prusa i3 MK3S')
    subscribe_to_request(request.id)

    request.push('added', printer:)
    deliver_events

    expect(pushes).to contain_exactly(include('state' => 'ADDED', 'printer' => {
                                                'id' => printer.id.to_s, 'name' => 'Prusa i3 MK3S', 'uri' => printer.uri
                                              }))
  end
end
