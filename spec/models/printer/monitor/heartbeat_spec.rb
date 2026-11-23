# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Monitor::Heartbeat do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  describe '.create!' do
    it 'stores the time of the beat, now by default' do
      freeze_time do
        described_class.create!

        expect(described_class.last.at).to eq Time.current
      end
    end
  end

  describe '.last' do
    it 'is nil without a heartbeat' do
      expect(described_class.last).to be_nil
    end

    it 'is nil when the heartbeat is unreadable' do
      redis.set('printer_monitor:heartbeat', 'garbage')

      expect(described_class.last).to be_nil
    end

    it 'reads the time as a TimeWithZone' do
      described_class.create!(at: 1.minute.ago)

      expect(described_class.last.at).to be_a(ActiveSupport::TimeWithZone).and be_within(0.001).of(1.minute.ago)
    end
  end

  describe '.healthy?' do
    it 'is false without a heartbeat' do
      expect(described_class.healthy?).to be false
    end

    it 'is true when the heartbeat is newer than 15 seconds' do
      described_class.create!
      travel 14.seconds

      expect(described_class.healthy?).to be true
    end

    it 'is false when the heartbeat is older than 15 seconds' do
      described_class.create!
      travel 16.seconds

      expect(described_class.healthy?).to be false
    end

    it 'is false when Redis is down' do
      allow(redis).to receive(:get).and_raise(Redis::CannotConnectError)

      expect(described_class.healthy?).to be false
    end
  end
end
