# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Backend::Octoprint::AppKey do
  describe '.url' do
    it 'builds the URL of an IPv4 address' do
      expect(described_class.url(IPAddr.new('192.168.1.57'))).to eq('http://192.168.1.57/')
    end

    it 'puts an IPv6 address in brackets' do
      expect(described_class.url(IPAddr.new('fd00::57'))).to eq('http://[fd00::57]/')
    end
  end

  # The probe is stubbed with WebMock, without VCR (spec/models/network_scan_spec.rb replays it with VCR)
  describe '.available?' do
    include WebMock::API

    around { |example| VCR.turned_off { example.run } }
    after { WebMock.reset! }

    let(:probe) { stub_request(:get, 'http://192.168.1.57/plugin/appkeys/probe') }

    it 'is true when the probe answers 204' do
      probe.to_return(status: 204)

      expect(described_class.available?('192.168.1.57')).to be(true)
    end

    it 'is false when the probe answers anything else' do
      probe.to_return(status: 200)

      expect(described_class.available?('192.168.1.57')).to be(false)
    end

    it 'is false when the plugin is missing (404)' do
      probe.to_return(status: 404)

      expect(described_class.available?('192.168.1.57')).to be(false)
    end

    it 'is false when the address does not answer' do
      probe.to_raise(Errno::ECONNREFUSED)

      expect(described_class.available?('192.168.1.57')).to be(false)
    end

    it 'is false on a timeout' do
      probe.to_timeout

      expect(described_class.available?('192.168.1.57')).to be(false)
    end
  end
end
