# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query monitorHealthy', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }
  let(:query) { 'query { monitorHealthy }' }
  let(:now) { Time.zone.local(2026, 11, 15, 12, 0, 0) }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    travel_to(now)
  end

  def monitor_healthy
    post('/graphql', params: { query: })
    response.parsed_body.dig('data', 'monitorHealthy')
  end

  it 'is true when the heartbeat is less than 15 seconds old' do
    PrinterStatusStore.beat!(at: now - 14.seconds)

    expect(monitor_healthy).to be(true)
  end

  it 'is false when the heartbeat is older than 15 seconds' do
    PrinterStatusStore.beat!(at: now - 16.seconds)

    expect(monitor_healthy).to be(false)
  end

  it 'becomes false as time passes without a heartbeat' do
    PrinterStatusStore.beat!(at: now)
    expect(monitor_healthy).to be(true)

    travel(20.seconds)
    expect(monitor_healthy).to be(false)
  end

  it 'is false when there is no heartbeat' do
    expect(monitor_healthy).to be(false)
  end
end
