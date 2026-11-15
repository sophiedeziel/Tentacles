# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer, :vcr, type: :model do
  let(:printer) { build(:printer) }

  it 'has a valid factory' do
    expect(printer).to be_valid
  end

  describe '.table_name_prefix' do
    it 'returns the default on the parent class' do
      expect(described_class.table_name_prefix).to eq ''
    end

    it 'has a prefix on the child classes' do
      test_class = Class.new(described_class)
      expect(test_class.table_name_prefix).to eq 'printer_'
    end
  end

  describe 'octoprint_version' do
    subject { printer.octoprint_version }

    it           { is_expected.to be_a(Octoprint::ServerVersion) }
    its(:api)    { is_expected.to eq('0.1') }
    its(:server) { is_expected.to eq('1.7.3') }
    its(:text)   { is_expected.to eq('OctoPrint 1.7.3') }
  end

  describe 'job_status' do
    subject { printer.job_status }

    it { is_expected.to eq 'Operational' }
  end

  describe 'jobs_count' do
    let!(:enqueued_printer_jobs) { create_list(:printer_job, 3, printer:, status: 'enqueued') }

    subject { printer.jobs_count }

    it { is_expected.to eq enqueued_printer_jobs.count }
  end

  describe 'queue' do
    let!(:enqueued_printer_jobs) { create_list(:printer_job, 3, printer:, status: 'enqueued') }
    let!(:completed_jobs) { create_list(:printer_job, 3, printer:, status: 'completed') }

    subject { printer.queue }

    it { is_expected.to eq enqueued_printer_jobs }
    it { is_expected.to_not include completed_jobs }
  end

  describe 'next_job' do
    let!(:enqueued_printer_jobs) { create_list(:printer_job, 3, printer:, status: 'enqueued') }

    subject { printer.next_job }

    it { is_expected.to eq enqueued_printer_jobs.first }
  end

  describe 'upload' do
    let(:file_path) { 'spec/fixture_files/test.gcode' }

    subject { printer.upload(file_path) }

    it { is_expected.to be_a(Octoprint::Files::OperationResult) }
    its(:done) { is_expected.to be_truthy }

    it 'uses a client with long timeouts for large files', vcr: { cassette_name: 'Printer/upload/1_8_1' } do
      allow(Octoprint::Client).to receive(:new).and_call_original
      subject
      expect(Octoprint::Client).to have_received(:new)
        .with(hash_including(host: printer.octoprint_uri, api_key: printer.octoprint_key,
                             open_timeout: 5, timeout: 120))
    end

    [Octoprint::Exceptions::ConnectionError, Octoprint::Exceptions::TimeoutError].each do |error_class|
      context "when the upload fails with #{error_class.name.demodulize}" do
        let(:printer) { create(:printer) }
        let(:redis) { MockRedis.new }

        before do
          stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
          allow(Octoprint::Files).to receive(:upload).and_raise(error_class, 'execution expired')
          allow(OctoprintCache).to receive(:set_disconnected)
        end

        it 'raises the error' do
          expect { subject }.to raise_error(error_class)
        end

        it 'does not mark the printer as disconnected' do
          expect { subject }.to raise_error(error_class)
          expect(OctoprintCache).not_to have_received(:set_disconnected)
          expect(OctoprintCache.disconnected?(printer.id)).to be false
        end
      end
    end
  end

  describe 'using_api' do
    subject do
      printer.using_api do
        Octoprint::ServerVersion.get
      end
    end

    context 'when octoprint is connected' do
      it 'returns the octoprint version' do
        expect(subject).to be_a(Octoprint::ServerVersion)
      end
    end

    context 'when octoprint is not available' do
      let(:printer) { build(:printer, :disconnected) }

      it 'raises an error' do
        expect { subject }.to raise_error(Octoprint::Exceptions::MissingCredentialsError)
      end
    end

    [
      [Octoprint::Exceptions::ConnectionError, 'Failed to open TCP connection to 10.0.1.165:80'],
      [Octoprint::Exceptions::TimeoutError, 'execution expired']
    ].each do |error_class, message|
      context "when octoprint cannot be reached (#{error_class.name.demodulize})" do
        let(:printer) { create(:printer) }
        let(:redis) { MockRedis.new }

        before do
          stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
          allow(Octoprint::ServerVersion).to receive(:get).and_raise(error_class, message)
        end

        it 'returns nil without raising' do
          expect(subject).to be_nil
        end

        it 'marks the printer as disconnected' do
          subject
          expect(OctoprintCache.disconnected?(printer.id)).to be true
        end
      end
    end

    context 'when octoprint is misconfigured' do
      let(:printer) { build(:printer, :wrong_credentials) }

      it 'raises an error' do
        expect { subject }.to raise_error(Octoprint::Exceptions::AuthenticationError)
      end
    end
  end
end
