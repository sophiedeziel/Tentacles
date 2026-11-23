# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::AppKeyRequest do
  let(:redis) { MockRedis.new }
  let(:app_token) { 'OCTOPRINT-APP-TOKEN-fedcba9876543210' }
  let(:attributes) do
    { address: '192.168.1.57', app_token:, approval_url: "http://192.168.1.57/plugin/appkeys/auth/#{app_token}" }
  end

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  def key(id)
    "printer_app_key_request_#{id}"
  end

  describe '.create!' do
    it 'generates a uuid id' do
      request = described_class.create!(**attributes)

      expect(request.id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      expect(described_class.create!(**attributes).id).not_to eq(request.id)
    end

    it 'writes its attributes as JSON under its id, for 15 minutes' do
      request = described_class.create!(**attributes)

      expect(JSON.parse(redis.get(key(request.id)))).to eq(attributes.stringify_keys.merge('id' => request.id))
      expect(redis.ttl(key(request.id))).to eq(15.minutes.to_i)
    end

    it 'keeps the id it is given' do
      described_class.create!(id: 'given-id', **attributes)

      expect(redis.get(key('given-id'))).to be_present
    end

    %i[address app_token approval_url].each do |attribute|
      it "raises ActiveModel::ValidationError and writes nothing without #{attribute}" do
        expect { described_class.create!(**attributes, attribute => '') }
          .to raise_error(ActiveModel::ValidationError, /can't be blank/)
        expect(redis.keys).to be_empty
      end
    end

    it 'is invalid with a blank id' do
      request = described_class.new(id: '', **attributes)

      expect(request.save).to be(false)
      expect(request.errors.attribute_names).to eq([:id])
      expect(redis.keys).to be_empty
    end
  end

  describe '.find' do
    it 'reads back every attribute' do
      request = described_class.create!(**attributes)

      expect(described_class.find(request.id)).to have_attributes(id: request.id, **attributes)
    end

    it 'leaves the request in Redis' do
      request = described_class.create!(**attributes)
      described_class.find(request.id)

      expect(described_class.find(request.id)).to be_present
    end

    it 'is nil when the request is over or expired' do
      expect(described_class.find('missing')).to be_nil
    end
  end

  describe '.take' do
    it 'returns the request and removes it, so that a second caller gets nil' do
      request = described_class.create!(**attributes)

      expect(described_class.take(request.id)).to have_attributes(id: request.id, **attributes)
      expect(redis.exists?(key(request.id))).to be(false)
      expect(described_class.take(request.id)).to be_nil
      expect(described_class.find(request.id)).to be_nil
    end

    it 'is nil when the request is already gone' do
      expect(described_class.take('missing')).to be_nil
    end
  end

  describe '#url' do
    it 'is the URL of an IPv4 address' do
      expect(described_class.new(address: '192.168.1.57').url).to eq('http://192.168.1.57/')
    end
  end

  describe '#payload' do
    let(:request) { described_class.new(id: 'request-id', **attributes) }

    it 'holds everything but the app token' do
      expect(request.payload('waiting')).to eq(id: 'request-id', address: '192.168.1.57',
                                               approval_url: attributes[:approval_url], state: 'waiting',
                                               printer: nil, error: nil)
    end

    it 'carries the printer and the error' do
      printer = build(:printer)

      expect(request.payload('added', printer:)).to include(state: 'added', printer:)
      expect(request.payload('failed', error: 'Unreachable')).to include(state: 'failed', error: 'Unreachable')
    end

    it 'rejects an unknown state' do
      expect { request.payload('approved') }.to raise_error(ArgumentError, 'Unknown state "approved"')
      expect { request.payload('WAITING') }.to raise_error(ArgumentError)
    end
  end
end
