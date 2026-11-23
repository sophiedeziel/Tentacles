# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GraphqlChannel, type: :channel do
  let(:printer) { create(:printer, name: 'Ender 3') }
  let(:printer_query) { 'query($id: ID!) { printer(id: $id) { name } }' }

  before do
    stub_connection
    subscribe
  end

  after { ActionCable.server.pubsub.clear }

  def execute(query, **data)
    perform('execute', query:, **data)
    transmissions.last
  end

  it 'transmits the result of a query, with nothing more to come' do
    payload = execute(printer_query, variables: { 'id' => printer.id.to_s })

    expect(payload).to eq('result' => { 'data' => { 'printer' => { 'name' => 'Ender 3' } } }, 'more' => false)
  end

  it 'reads the variables from a JSON string' do
    other = create(:printer, name: 'Prusa MK4')

    payload = execute(printer_query, variables: { id: other.id.to_s }.to_json)

    expect(payload.dig('result', 'data', 'printer')).to eq('name' => 'Prusa MK4')
  end

  it 'runs without variables when they are nil or blank' do
    payloads = [nil, ''].map { |variables| execute('{ printers { name } }', variables:) }

    expect(payloads.pluck('result')).to all(eq('data' => { 'printers' => [] }))
  end

  it 'rejects variables of an unexpected type' do
    expect { perform('execute', query: printer_query, variables: 42) }
      .to raise_error(ArgumentError, 'Unexpected parameter: 42')
  end

  it 'runs the operation named by operationName' do
    query = <<~GRAPHQL
      query Name($id: ID!) { printer(id: $id) { name } }
      query Uri($id: ID!) { printer(id: $id) { uri } }
    GRAPHQL

    payload = execute(query, variables: { 'id' => printer.id.to_s }, operationName: 'Uri')

    expect(payload.dig('result', 'data')).to eq('printer' => { 'uri' => 'http://10.0.1.165/' })
  end

  describe 'subscriptions' do
    let(:subscriptions) { TentaclesSchema.subscriptions }
    let(:subscription_id) do
      prefix = GraphQL::Subscriptions::ActionCableSubscriptions::SUBSCRIPTION_PREFIX
      subscription.streams.find { |stream| stream.start_with?(prefix) }.delete_prefix(prefix)
    end

    it 'transmits that more is to come and forgets the subscription on unsubscribe' do
      payload = execute('subscription { printerStatusChanged { id } }')

      expect(payload['more']).to be(true)
      expect(subscriptions.read_subscription(subscription_id)).to be_present

      unsubscribe

      expect(subscriptions.read_subscription(subscription_id)).to be_nil
    end
  end
end
