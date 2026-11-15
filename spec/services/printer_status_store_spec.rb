# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterStatusStore do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }
  let(:status) do
    PrinterStatus.new(printer_id: 7, state_family: PrinterStateFamily::Operational, state_text: 'Operational')
  end

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  describe '.write' do
    it 'stores the snapshot as JSON under printer_status:<id>' do
      described_class.write(status)

      expect(JSON.parse(redis.get('printer_status:7'))).to include('state_family' => 'OPERATIONAL')
    end
  end

  describe '.read_many' do
    before do
      described_class.write(status)
      described_class.write(PrinterStatus.unknown(printer_id: 8))
    end

    it 'reads every snapshot with a single MGET' do
      expect(redis).to receive(:mget).once.and_call_original
      expect(redis).not_to receive(:get)

      expect(described_class.read_many([7, 8, 9])).to eq(7 => status, 8 => PrinterStatus.unknown(printer_id: 8))
    end

    it 'does not call Redis without printers' do
      expect(redis).not_to receive(:mget)

      expect(described_class.read_many([])).to eq({})
    end

    it 'skips unreadable snapshots' do
      redis.set('printer_status:8', 'not json')

      expect(described_class.read_many([7, 8])).to eq(7 => status)
    end
  end

  describe '.read' do
    it 'reads one snapshot' do
      described_class.write(status)

      expect(described_class.read(7)).to eq status
      expect(described_class.read(8)).to be_nil
    end
  end

  describe '.delete' do
    it 'deletes the snapshots' do
      described_class.write(status)
      described_class.delete([7])

      expect(redis.get('printer_status:7')).to be_nil
    end
  end

  describe '.monitor_healthy?' do
    it 'is false without a heartbeat' do
      expect(described_class.monitor_healthy?).to be false
    end

    it 'is true when the heartbeat is newer than 15 seconds' do
      described_class.beat!
      travel 14.seconds

      expect(described_class.monitor_healthy?).to be true
    end

    it 'is false when the heartbeat is older than 15 seconds' do
      described_class.beat!
      travel 16.seconds

      expect(described_class.monitor_healthy?).to be false
    end

    it 'is false when Redis is down' do
      allow(redis).to receive(:get).and_raise(Redis::CannotConnectError)

      expect(described_class.monitor_healthy?).to be false
    end

    it 'is false when the heartbeat is unreadable' do
      redis.set('printer_monitor:heartbeat', 'garbage')

      expect(described_class.monitor_healthy?).to be false
    end
  end
end
