# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Disconnection do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  describe '.create!' do
    it 'stores the expiration as JSON under printer_<id>_disconnected, 10 minutes from now by default' do
      freeze_time do
        described_class.create!(printer_id: 1)

        expect(JSON.parse(redis.get('printer_1_disconnected'))).to eq('expiration' => 10.minutes.from_now.to_i)
      end
    end
  end

  describe '.exists?' do
    it 'is true for 10 minutes' do
      described_class.create!(printer_id: 1)

      expect(described_class.exists?(printer_id: 1)).to be true
      expect(described_class.exists?(printer_id: 2)).to be false
      travel 11.minutes
      expect(described_class.exists?(printer_id: 1)).to be false
    end

    it 'follows a custom duration' do
      described_class.create!(printer_id: 1, expires_in: 1.minute)
      travel 2.minutes

      expect(described_class.exists?(printer_id: 1)).to be false
    end
  end

  describe '.delete_by' do
    it "deletes the printer's flag only" do
      described_class.create!(printer_id: 1)
      described_class.create!(printer_id: 2)

      described_class.delete_by(printer_id: 1)

      expect(redis.keys).to eq ['printer_2_disconnected']
    end
  end
end
