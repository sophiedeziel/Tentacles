# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterScanner do
  describe '#call' do
    let(:service) { described_class.new }
    subject { service.call }

    before do
      allow(service).to receive(:`).and_return(File.read('spec/fixture_files/nmap_result.txt').to_s)
    end

    after(:each) do
      Redis.current.set(:printers_ips, nil)
      Redis.current.set(:last_printer_scan, nil)
    end

    context 'when there are no printers' do
      before do
        allow(service).to receive(:all_network_ips).and_return(['192.168.0.4'])
      end

      it 'returns an array of IPs' do
        expect(subject).to be_a(Array)
        expect(subject).to be_empty
      end
    end

    context 'when there is a printer', :vcr do
      it 'returns an array of IPs' do
        expect(subject).to be_a(Array)
        expect(subject.first).to eq '10.0.1.165'
      end

      describe 'cashing' do
        it 'caches the result' do
          subject
          expect(Redis.current.get(:printers_ips)).to eq '["10.0.1.165"]'
          expect(Redis.current.get(:last_printer_scan)).to be_present
        end

        it 'uses the cache' do
          Redis.current.set(:printers_ips, ['192.168.0.5'])
          Redis.current.set(:last_printer_scan, 3.minutes.ago.to_i)
          expect(subject).to eq ['192.168.0.5']
        end
      end
    end
  end
end
