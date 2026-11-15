# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterApiCache do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  def use_cache(time: 2.hours, &)
    described_class.use_cache(id: 1, method: 'version', time:, &)
  end

  [
    'OctoPrint 1.11.2',
    { name: 'cube.gcode', progress: 42.1 },
    [1, 'two']
  ].each do |value|
    it "returns a cached #{value.class} as it was stored" do
      use_cache { value }
      expect(use_cache { raise 'not cached' }).to eq value
    end
  end

  it 'calls the API again once the cache expired' do
    use_cache { 'old' }
    travel_to(3.hours.from_now) do
      expect(use_cache { 'new' }).to eq 'new'
    end
  end

  it 'ignores the entries of the previous cache format' do
    redis.set('printer_1_version', { value: { text: 'OctoPrint 1.7.3' }, object_type: 'Octoprint::ServerVersion',
                                     expiration: 1.hour.from_now.to_i }.to_json)
    expect(use_cache { 'OctoPrint 1.11.2' }).to eq 'OctoPrint 1.11.2'
  end

  it 'does not call the API of a disconnected printer' do
    described_class.set_disconnected(1)
    expect(use_cache { raise 'called' }).to be_nil
  end
end
