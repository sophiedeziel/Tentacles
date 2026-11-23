# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::DispatchRequest do
  # MockRedis doesn't implement PUBLISH
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(redis).to receive(:publish)
    allow(PrintQueue).to receive(:enabled?).and_return(true)
  end

  it 'asks the spooler for a dispatch pass, without a printer' do
    expect(described_class.new.save).to be true
    expect(redis).to have_received(:publish).once.with('printers', '{"command":"dispatch"}')
  end

  it 'publishes nothing while the global queue is off' do
    allow(PrintQueue).to receive(:enabled?).and_return(false)

    expect(described_class.new.save).to be true
    expect(redis).not_to have_received(:publish)
  end

  [Redis::CannotConnectError, ConnectionPool::TimeoutError].each do |error|
    it "logs #{error.name} without raising" do
      allow(redis).to receive(:publish).and_raise(error, 'Connection refused')
      allow(Rails.logger).to receive(:error)

      expect(described_class.new.save).to be true
      expect(Rails.logger).to have_received(:error).with(/Could not publish dispatch: #{error.name}/)
    end
  end
end
