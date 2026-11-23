# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::QueueChanged do
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
  let(:query) { 'subscription { queueChanged { dispatchPaused } }' }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(PrintQueue).to receive(:enabled?).and_return(true)
  end

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

  def pushed(dispatch_paused)
    { 'result' => { 'data' => { 'queueChanged' => { 'dispatchPaused' => dispatch_paused } } }, 'more' => true }
  end

  it 'returns a non-null QueueChange with dispatchPaused, and takes no arguments' do
    field = TentaclesSchema.subscription.get_field('queueChanged')

    expect(field.type.to_type_signature).to eq('QueueChange!')
    expect(field.arguments).to be_empty
    expect(TentaclesSchema.get_type('QueueChange').fields.transform_values { |f| f.type.to_type_signature })
      .to eq('dispatchPaused' => 'Boolean!')
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

  it 'pushes whether dispatch is paused to every subscriber, reading it once (broadcast)' do
    PrintQueue::Setting.current.update!(dispatch_paused: true)
    first = subscribe.context[:subscription_id]
    second = subscribe.context[:subscription_id]
    expect(PrintQueue::Setting).to receive(:dispatch_paused?).once.and_call_original

    PrintQueue.push_changed
    deliver_events

    [first, second].each { |subscription_id| expect(deliveries(subscription_id)).to eq [pushed(true)] }
  end

  it 'is pushed once by a queue operation, after its change' do
    printer = create(:printer)
    job = create(:print_job, copies: 2, same_printer: true, bound_printer: printer)
    subscription_id = subscribe.context[:subscription_id]

    expect(PrintQueue::Hold.new(job:).save).to be true
    deliver_events

    expect(deliveries(subscription_id)).to eq [pushed(false)]
  end

  it 'is pushed by pauseDispatch, with dispatch paused' do
    subscription_id = subscribe.context[:subscription_id]

    result = TentaclesSchema.execute('mutation { pauseDispatch(input: {}) { success } }')
    deliver_events

    expect(result.dig('data', 'pauseDispatch', 'success')).to be true
    expect(deliveries(subscription_id)).to eq [pushed(true)]
  end

  it 'is pushed by setPrinterTakesJobs' do
    printer = create(:printer)
    subscription_id = subscribe.context[:subscription_id]

    expect(Printer::TakesJobsChange.new(printer:, takes_jobs: false).save).to be true
    deliver_events

    expect(deliveries(subscription_id)).to eq [pushed(false)]
  end

  it "is pushed when a printer's own job changes status" do
    job = create(:printer_job)
    subscription_id = subscribe.context[:subscription_id]

    job.update!(status: 'active')
    job.push_print_queue_changed
    deliver_events

    expect(deliveries(subscription_id)).to eq [pushed(false)]
  end

  it 'is pushed when a printer is removed' do
    printer = create(:printer)
    subscription_id = subscribe.context[:subscription_id]

    Printer::Removal.new(printer:).save!
    deliver_events

    expect(deliveries(subscription_id)).to eq [pushed(false)]
  end

  it 'is not pushed while the global queue is off' do
    subscription_id = subscribe.context[:subscription_id]
    allow(PrintQueue).to receive(:enabled?).and_return(false)

    PrintQueue.push_changed([create(:printer)])
    deliver_events

    expect(deliveries(subscription_id)).to be_empty
  end
end
