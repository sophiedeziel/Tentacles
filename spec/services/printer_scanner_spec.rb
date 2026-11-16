# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterScanner do
  describe '#call' do
    let(:service) { described_class.new }
    let(:redis) { MockRedis.new }

    before do
      stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
      allow(service).to receive(:local_ip).and_return('10.0.1.20')
      allow(service).to receive(:`).and_return(File.read('spec/fixture_files/nmap_result.txt').to_s)
    end

    context 'when no address answers the probe' do
      before do
        allow(service).to receive(:all_network_ips).and_return(['192.168.0.4'])
        allow(service).to receive(:octoprint?).and_return(false)
      end

      it 'returns an empty array' do
        expect(service.call).to eq([])
      end
    end

    # The probe answers of the addresses in nmap_result.txt: only 10.0.1.165 is an OctoPrint
    context 'when there is a printer',
            vcr: { cassette_name: 'PrinterScanner/_call/when_there_is_a_printer/returns_an_array_of_IPs',
                   record: :none } do
      it 'returns the addresses that answer the appkeys probe' do
        expect(service.call).to eq(['10.0.1.165'])
      end

      it 'keeps the addresses of the saved printers' do
        create(:printer, uri: 'http://10.0.1.165/')

        expect(service.call).to eq(['10.0.1.165'])
      end

      it 'caches the result' do
        service.call

        expect(redis.get(:printers_ips)).to eq('["10.0.1.165"]')
        expect(redis.get(:last_printer_scan)).to be_present
      end
    end

    context 'with a scan from 3 minutes ago in the cache' do
      before do
        redis.set(:printers_ips, ['192.168.0.5'].to_json)
        redis.set(:last_printer_scan, 3.minutes.ago.to_i)
        allow(service).to receive(:all_network_ips).and_return(['192.168.0.6'])
        allow(service).to receive(:octoprint?).and_return(true)
      end

      it 'uses the cache without scanning' do
        expect(service.call).to eq(['192.168.0.5'])
        expect(service).not_to have_received(:all_network_ips)
      end

      it 'scans again with refresh: true, and caches the new scan' do
        expect(service.call(refresh: true)).to eq(['192.168.0.6'])
        expect(redis.get(:printers_ips)).to eq('["192.168.0.6"]')
      end
    end

    it 'scans again when the cached scan is older than 15 minutes' do
      redis.set(:printers_ips, ['192.168.0.5'].to_json)
      redis.set(:last_printer_scan, 16.minutes.ago.to_i)
      allow(service).to receive_messages(all_network_ips: ['192.168.0.6'], octoprint?: true)

      expect(service.call).to eq(['192.168.0.6'])
    end
  end

  describe '#last_scan' do
    let(:service) { described_class.new }
    let(:redis) { MockRedis.new }

    before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

    it 'returns the addresses of the last scan, however old, without scanning' do
      redis.set(:printers_ips, ['192.168.0.5'].to_json)
      redis.set(:last_printer_scan, 1.day.ago.to_i)
      allow(service).to receive(:network_scan)

      expect(service.last_scan).to eq(['192.168.0.5'])
      expect(service).not_to have_received(:network_scan)
    end

    it 'is empty before the first scan' do
      expect(service.last_scan).to eq([])
    end
  end
end
