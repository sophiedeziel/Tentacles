# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::PrinterStatusChanged do
  # Stands in for GraphqlChannel: records the ActionCable streams that the subscriptions open
  let(:channel_class) do
    Class.new do
      attr_reader :streams

      def initialize
        @streams = Hash.new { |hash, name| hash[name] = [] }
      end

      def stream_from(name, coder: nil, &callback)
        @streams[name] << { coder:, callback: }
      end
    end
  end
  let(:channel) { channel_class.new }
  let(:redis) { MockRedis.new }
  let(:subscriptions) { TentaclesSchema.subscriptions }
  let(:pubsub) { ActionCable.server.pubsub }
  let(:subscription_ids) { [] }

  let(:status_changed_query) do
    'subscription { printerStatusChanged { id name status { stateFamily hotend { actual } camera { streamUrl } } } }'
  end
  let(:printer_subscription_query) { 'subscription($id: ID!) { printerSubscription(id: $id) { printer { id } } }' }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  after do
    subscription_ids.each { |id| subscriptions.delete_subscription(id) }
    pubsub.clear
  end

  def subscribe(query, variables: {})
    result = TentaclesSchema.execute(query, variables:, context: { channel: })
    subscription_ids << result.context[:subscription_id] if result.context[:subscription_id]
    result
  end

  # Replays what ActionCable does with a trigger broadcast: hands the message to every callback of the event stream
  # (graphql-ruby runs the broadcast update in the callback of the first subscriber only)
  def deliver_events
    channel.streams.each do |name, callbacks|
      next unless name.start_with?(GraphQL::Subscriptions::ActionCableSubscriptions::EVENT_PREFIX)

      pubsub.broadcasts(name).product(callbacks).each do |message, stream|
        stream[:callback].call(stream[:coder].decode(message))
      end
    end
  end

  def deliveries(subscription_id)
    name = "#{GraphQL::Subscriptions::ActionCableSubscriptions::SUBSCRIPTION_PREFIX}#{subscription_id}"
    pubsub.broadcasts(name).map { |message| JSON.parse(message) }
  end

  describe 'field' do
    let(:field) { TentaclesSchema.subscription.get_field('printerStatusChanged') }

    it 'returns a non-null Printer and takes no arguments' do
      expect(field.type.to_type_signature).to eq('Printer!')
      expect(field.arguments).to be_empty
    end
  end

  describe 'broadcastable?' do
    it 'broadcasts printerStatusChanged' do
      expect(subscriptions.broadcastable?(status_changed_query)).to be(true)
    end

    it 'does not broadcast printerSubscription' do
      expect(subscriptions.broadcastable?(printer_subscription_query, variables: { 'id' => '1' })).to be(false)
    end
  end

  describe 'execution' do
    let(:printer) { create(:printer, name: 'Ender 3') }

    before do
      PrinterStatusStore.write(
        PrinterStatus.new(
          printer_id: printer.id,
          state_family: PrinterStateFamily::Operational,
          state_text: 'Operational',
          hotend: PrinterStatus::Temperature.new(actual: 24.5, target: 0.0),
          camera: PrinterStatus::Camera.new(enabled: true, stream_url: 'http://octopi.local/webcam/?action=stream')
        )
      )
    end

    it 'sends nothing on subscribe' do
      result = subscribe(status_changed_query)

      expect(result['errors']).to be_nil
      expect(result['data']).to be_blank
      expect(result.context[:subscription_id]).to be_present
    end

    it "pushes the triggered printer's status to every subscriber, running the update once (broadcast)" do
      first = subscribe(status_changed_query).context[:subscription_id]
      second = subscribe(status_changed_query).context[:subscription_id]
      expect(redis).to receive(:mget).once.and_call_original

      subscriptions.trigger(:printer_status_changed, {}, printer)
      deliver_events

      expected = {
        'id' => printer.id.to_s,
        'name' => 'Ender 3',
        'status' => {
          'stateFamily' => 'OPERATIONAL',
          'hotend' => { 'actual' => 25.0 },
          'camera' => { 'streamUrl' => 'http://octopi.local/webcam/?action=stream' }
        }
      }
      [first, second].each do |subscription_id|
        expect(deliveries(subscription_id)).to eq(
          [{ 'result' => { 'data' => { 'printerStatusChanged' => expected } }, 'more' => true }]
        )
      end
    end
  end

  describe 'printerSubscription' do
    let(:printer) { create(:printer) }

    it 'still subscribes and returns the printer' do
      result = subscribe(printer_subscription_query, variables: { 'id' => printer.id.to_s })

      expect(result['errors']).to be_nil
      expect(result['data']).to eq('printerSubscription' => { 'printer' => { 'id' => printer.id.to_s } })
      expect(result.context[:subscription_id]).to be_present
    end
  end
end
