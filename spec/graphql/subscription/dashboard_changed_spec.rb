# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::DashboardChanged do
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

  # Everything the dashboard reads, down to each widget's printer and its live status
  let(:query) do
    <<~GRAPHQL
      subscription {
        dashboardChanged {
          updatedAt
          sections {
            id
            title
            widgets {
              id
              type
              widthUnits
              heightUnits
              printer { id name canStartNext status { stateFamily printTimeLeft hotend { actual unit } } }
              options {
                __typename
                ... on PrinterWidgetOptions { camera timeLeft temperatures upNext controls }
                ... on PrintQueueWidgetOptions { nowPrinting startNext rowPerPrinter history }
              }
            }
          }
        }
      }
    GRAPHQL
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

  it 'returns a non-null Dashboard and takes no arguments' do
    field = TentaclesSchema.subscription.get_field('dashboardChanged')

    expect(field.type.to_type_signature).to eq('Dashboard!')
    expect(field.arguments).to be_empty
  end

  it 'is broadcastable, options and printers included' do
    expect(subscriptions.broadcastable?(query)).to be(true)
  end

  it 'sends nothing on subscribe' do
    result = subscribe

    expect(result['errors']).to be_nil
    expect(result['data']).to be_blank
    expect(result.context[:subscription_id]).to be_present
  end

  it 'pushes the saved layout to every subscriber, running the update once (broadcast)' do
    printer = create(:printer, name: 'Prusa MK4')
    Dashboard::Section.ensure_default!
    first = subscribe.context[:subscription_id]
    second = subscribe.context[:subscription_id]
    expect(Types::Dashboard).to receive(:saved).once.and_call_original

    subscriptions.trigger(:dashboard_changed, {}, {})
    deliver_events

    [first, second].each do |subscription_id|
      widgets = deliveries(subscription_id).sole.dig('result', 'data', 'dashboardChanged', 'sections', 0, 'widgets')
      expect(widgets.map { |widget| widget.values_at('type', 'widthUnits', 'heightUnits') })
        .to eq([['PRINT_QUEUE', 4, 2], ['PRINTER', 2, 1]])
      expect(widgets.last['printer']).to eq(
        'id' => printer.id.to_s, 'name' => 'Prusa MK4', 'canStartNext' => false,
        'status' => { 'stateFamily' => 'OFFLINE', 'printTimeLeft' => nil, 'hotend' => nil }
      )
    end
  end
end
