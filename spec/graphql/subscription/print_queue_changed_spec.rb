# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::PrintQueueChanged do
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

  # What the dashboard selects: the queue fields of the printer, refreshed by the push
  let(:query) do
    'subscription { printQueueChanged { id queuedCount canStartNext nextJob { id executable { filename } } } }'
  end

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  after do
    subscription_ids.each { |id| subscriptions.delete_subscription(id) }
    pubsub.clear
  end

  def subscribe
    result = TentaclesSchema.execute(query, context: { channel: })
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

  it 'returns a non-null Printer and takes no arguments' do
    field = TentaclesSchema.subscription.get_field('printQueueChanged')

    expect(field.type.to_type_signature).to eq('Printer!')
    expect(field.arguments).to be_empty
  end

  it 'is broadcast' do
    expect(subscriptions.broadcastable?(query)).to be(true)
  end

  it 'sends nothing on subscribe' do
    result = subscribe

    expect(result['errors']).to be_nil
    expect(result['data']).to be_blank
    expect(result.context[:subscription_id]).to be_present
  end

  it "pushes the printer's new queue fields to every subscriber when a job is enqueued" do
    printer = create(:printer)
    PrinterStatusStore.write(PrinterStatus.new(printer_id: printer.id, state_family: PrinterStateFamily::Operational,
                                               state_text: 'Operational',
                                               camera: PrinterStatus::Camera.new(enabled: false)))
    first = subscribe.context[:subscription_id]
    second = subscribe.context[:subscription_id]

    job = create(:printer_job, printer:)
    deliver_events

    expected = { 'id' => printer.id.to_s, 'queuedCount' => 1, 'canStartNext' => true,
                 'nextJob' => { 'id' => job.id.to_s, 'executable' => { 'filename' => 'test.gcode' } } }
    [first, second].each do |subscription_id|
      expect(deliveries(subscription_id)).to eq(
        [{ 'result' => { 'data' => { 'printQueueChanged' => expected } }, 'more' => true }]
      )
    end
  end

  it 'pushes a removed printer with an empty queue, without contacting it' do
    printer = create(:printer)
    create(:printer_job, printer:)
    pubsub.clear # the push of the create
    subscription_id = subscribe.context[:subscription_id]
    allow(PrinterBackends).to receive(:for)

    Printers::Remove.call(printer)
    deliver_events

    expected = { 'id' => printer.id.to_s, 'queuedCount' => 0, 'canStartNext' => false, 'nextJob' => nil }
    expect(deliveries(subscription_id)).to eq(
      [{ 'result' => { 'data' => { 'printQueueChanged' => expected } }, 'more' => true }]
    )
    expect(PrinterBackends).not_to have_received(:for)
  end

  it 'pushes nothing on progress updates' do
    job = create(:printer_job, status: 'active')
    pubsub.clear # the push of the create
    subscription_id = subscribe.context[:subscription_id]

    job.update!(progress: 42)
    deliver_events

    expect(deliveries(subscription_id)).to be_empty
  end
end
