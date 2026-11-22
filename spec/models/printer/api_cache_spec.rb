# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::ApiCache do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  def cached(printer_id: 1, api_method: 'version', &)
    described_class.find_or_create_by(printer_id:, api_method:, expires_in: 2.hours, &).value
  end

  describe '.find_or_create_by' do
    [
      'OctoPrint 1.11.2',
      { name: 'cube.gcode', progress: 42.1 },
      [1, 'two']
    ].each do |value|
      it "returns a cached #{value.class} as it was stored" do
        cached { value }
        expect(cached { raise 'not cached' }).to eq value
      end
    end

    it 'stores the answer as JSON under printer_api_<id>_<method>, with its expiration' do
      freeze_time do
        cached { 'OctoPrint 1.11.2' }

        expect(JSON.parse(redis.get('printer_api_1_version')))
          .to eq('value' => 'OctoPrint 1.11.2', 'expiration' => 2.hours.from_now.to_i)
      end
    end

    it 'calls the API again once the cache expired' do
      cached { 'old' }
      travel_to(3.hours.from_now) do
        expect(cached { 'new' }).to eq 'new'
      end
    end

    it 'calls the API again when the cached answer is blank' do
      cached { nil }
      expect(cached { 'OctoPrint 1.11.2' }).to eq 'OctoPrint 1.11.2'
    end

    it 'ignores the entries of the previous cache format' do
      redis.set('printer_1_version', { value: { text: 'OctoPrint 1.7.3' }, object_type: 'Octoprint::ServerVersion',
                                       expiration: 1.hour.from_now.to_i }.to_json)
      expect(cached { 'OctoPrint 1.11.2' }).to eq 'OctoPrint 1.11.2'
    end
  end

  describe '.find_by' do
    it 'reads the cached answer, nil when there is none' do
      cached { 'OctoPrint 1.11.2' }

      expect(described_class.find_by(printer_id: 1, api_method: 'version'))
        .to have_attributes(value: 'OctoPrint 1.11.2', expires_at: be_within(1.second).of(2.hours.from_now))
      expect(described_class.find_by(printer_id: 1, api_method: 'job_status')).to be_nil
    end
  end

  describe '#destroy' do
    it 'deletes the cached answer' do
      cached { 'OctoPrint 1.11.2' }

      described_class.find_by(printer_id: 1, api_method: 'version').destroy

      expect(redis.keys).to be_empty
    end
  end

  describe '.delete_by' do
    it "deletes the printer's cached answers, not those of other printers" do
      cached { 'OctoPrint 1.11.2' }
      cached(api_method: 'job_status') { 'Printing' }
      cached(printer_id: 12) { 'OctoPrint 1.10.0' }

      described_class.delete_by(printer_id: 1)

      expect(redis.keys).to eq ['printer_api_12_version']
    end

    it 'does nothing for a printer without keys' do
      expect { described_class.delete_by(printer_id: 1) }.not_to raise_error
    end
  end
end
