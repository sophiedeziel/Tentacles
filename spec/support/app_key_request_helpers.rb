# frozen_string_literal: true

require 'webmock/rspec/matchers'

# For the OctoPrint approval specs (require 'support/app_key_request_helpers'): a MockRedis, subscribers to
# printerAppKeyChanged through a stand-in GraphqlChannel, everything that was logged, and the API key that
# OctoPrint hands out, which none of them may contain.
module AppKeyRequestHelpers
  extend ActiveSupport::Concern

  API_KEY = 'OCTOPRINT-API-KEY-0123456789abcdef'
  APP_TOKEN = 'OCTOPRINT-APP-TOKEN-fedcba9876543210'

  # Stands in for GraphqlChannel: records the ActionCable streams that the subscriptions open
  class Channel
    attr_reader :streams

    def initialize
      @streams = Hash.new { |hash, name| hash[name] = [] }
    end

    def stream_from(name, coder: nil, &callback)
      @streams[name] << { coder:, callback: }
    end
  end

  included do
    # OctoPrint is stubbed with WebMock, without VCR
    include WebMock::API
    include WebMock::Matchers

    around { |example| VCR.turned_off { example.run } }
    after { WebMock.reset! }

    let(:redis) { MockRedis.new }
    let(:channel) { Channel.new }
    let(:pubsub) { ActionCable.server.pubsub }
    let(:subscription_ids) { [] }
    let(:log) { StringIO.new }
    let(:log_capture) { ActiveSupport::Logger.new(log).tap { |logger| logger.level = :debug } }

    before do
      stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
      Rails.logger.broadcast_to(log_capture)
    end

    after do
      Rails.logger.stop_broadcasting_to(log_capture)
      subscription_ids.each { |id| TentaclesSchema.subscriptions.delete_subscription(id) }
      pubsub.clear
    end
  end

  def subscribe_to_request(id, fields: 'id address state approvalUrl error printer { id name uri }')
    result = TentaclesSchema.execute("subscription { printerAppKeyChanged(id: \"#{id}\") { #{fields} } }",
                                     context: { channel: })
    subscription_ids << result.context[:subscription_id]
    result
  end

  # Replays what ActionCable does with a trigger broadcast: hands the message to every callback of the event stream
  def deliver_events
    channel.streams.each do |name, callbacks|
      next unless name.start_with?(GraphQL::Subscriptions::ActionCableSubscriptions::EVENT_PREFIX)

      pubsub.broadcasts(name).product(callbacks).each do |message, stream|
        stream[:callback].call(stream[:coder].decode(message))
      end
    end
  end

  # The printerAppKeyChanged results pushed to a subscriber
  def pushes(subscription_id = subscription_ids.first)
    name = "#{GraphQL::Subscriptions::ActionCableSubscriptions::SUBSCRIPTION_PREFIX}#{subscription_id}"
    pubsub.broadcasts(name).map { |message| JSON.parse(message).dig('result', 'data', 'printerAppKeyChanged') }
  end

  # Everything that went out on ActionCable: the trigger events and the pushes
  def all_broadcasts
    channel.streams.keys.flat_map { |name| pubsub.broadcasts(name) } +
      subscription_ids.flat_map do |id|
        pubsub.broadcasts("#{GraphQL::Subscriptions::ActionCableSubscriptions::SUBSCRIPTION_PREFIX}#{id}")
      end
  end

  def octoprint_url(path = '')
    "http://192.168.1.57/#{path}"
  end

  # Waiting in OctoPrint, as requestPrinterAppKey leaves it
  def create_request(app_token: APP_TOKEN)
    Printer::AppKeyRequest.create!(address: '192.168.1.57', app_token:,
                                   approval_url: octoprint_url("plugin/appkeys/auth/#{app_token}"))
  end
end
