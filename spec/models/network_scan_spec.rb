# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NetworkScan do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  describe '#save!' do
    let(:scan) { described_class.new }

    before do
      allow(scan).to receive(:local_ip).and_return('10.0.1.20')
      allow(scan).to receive(:`).and_return(File.read('spec/fixture_files/nmap_result.txt').to_s)
    end

    context 'when no address answers the probe' do
      before do
        allow(scan).to receive(:all_network_ips).and_return(['192.168.0.4'])
        allow(Printer::Backend::Octoprint::AppKey).to receive(:available?).and_return(false)
      end

      it 'finds no ips' do
        scan.save!

        expect(scan.ips).to eq([])
      end
    end

    # The probe answers of the addresses in nmap_result.txt: only 10.0.1.165 is an OctoPrint
    context 'when there is a printer',
            vcr: { cassette_name: 'NetworkScan/when_there_is_a_printer', record: :none } do
      it 'finds the addresses that answer the appkeys probe' do
        scan.save!

        expect(scan.ips).to eq(['10.0.1.165'])
      end

      it 'keeps the addresses of the saved printers' do
        create(:printer, uri: 'http://10.0.1.165/')
        scan.save!

        expect(scan.ips).to eq(['10.0.1.165'])
      end

      it 'stores the scan' do
        freeze_time do
          scan.save!

          expect(redis.get(:printers_ips)).to eq('["10.0.1.165"]')
          expect(redis.get(:last_printer_scan)).to eq(Time.current.to_i.to_s)
          expect(scan.scanned_at).to eq(Time.current)
        end
      end
    end

    context 'with a scan from 3 minutes ago in Redis' do
      before do
        redis.set(:printers_ips, ['192.168.0.5'].to_json)
        redis.set(:last_printer_scan, 3.minutes.ago.to_i)
        allow(scan).to receive(:all_network_ips).and_return(['192.168.0.6'])
        allow(Printer::Backend::Octoprint::AppKey).to receive(:available?).and_return(true)
      end

      it 'reuses it without scanning' do
        scan.save!

        expect(scan.ips).to eq(['192.168.0.5'])
        expect(scan).not_to have_received(:all_network_ips)
      end

      it 'scans again with refresh: true, and stores the new scan' do
        scan.refresh = true
        scan.save!

        expect(scan.ips).to eq(['192.168.0.6'])
        expect(redis.get(:printers_ips)).to eq('["192.168.0.6"]')
      end
    end

    it 'scans again when the last scan is older than 15 minutes' do
      redis.set(:printers_ips, ['192.168.0.5'].to_json)
      redis.set(:last_printer_scan, 16.minutes.ago.to_i)
      allow(scan).to receive(:all_network_ips).and_return(['192.168.0.6'])
      allow(Printer::Backend::Octoprint::AppKey).to receive(:available?).and_return(true)

      scan.save!

      expect(scan.ips).to eq(['192.168.0.6'])
    end
  end

  describe '.last' do
    it 'returns the last scan, however old, without scanning' do
      freeze_time do
        redis.set(:printers_ips, ['192.168.0.5'].to_json)
        redis.set(:last_printer_scan, 1.day.ago.to_i)
        allow(Socket).to receive(:ip_address_list)

        expect(described_class.last).to have_attributes(ips: ['192.168.0.5'], scanned_at: 1.day.ago)
        expect(Socket).not_to have_received(:ip_address_list)
      end
    end

    it 'is nil before the first scan' do
      expect(described_class.last).to be_nil
    end
  end
end
