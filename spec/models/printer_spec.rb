# frozen_string_literal: true

require 'rails_helper'
require 'support/unreadable_secret'

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

    it { is_expected.to eq('OctoPrint 1.7.3') }
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

    it 'uploads the file', vcr: { cassette_name: 'Printer/upload/1_8_1' } do
      expect { subject }.not_to raise_error
    end

    it 'uses a client with long timeouts for large files', vcr: { cassette_name: 'Printer/upload/1_8_1' } do
      allow(Octoprint::Client).to receive(:new).and_call_original
      subject
      expect(Octoprint::Client).to have_received(:new)
        .with(hash_including(host: printer.uri, api_key: printer.secret, open_timeout: 5, timeout: 120))
    end

    [Octoprint::Exceptions::ConnectionError, Octoprint::Exceptions::TimeoutError].each do |error_class|
      context "when the upload fails with #{error_class.name.demodulize}" do
        let(:printer) { create(:printer) }
        let(:redis) { MockRedis.new }

        before do
          stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
          allow(Octoprint::Files).to receive(:upload).and_raise(error_class, 'execution expired')
          allow(PrinterApiCache).to receive(:set_disconnected)
        end

        it 'raises the error' do
          expect { subject }.to raise_error(PrinterBackends::Unreachable, 'execution expired')
        end

        it 'does not mark the printer as disconnected' do
          expect { subject }.to raise_error(PrinterBackends::Unreachable)
          expect(PrinterApiCache).not_to have_received(:set_disconnected)
          expect(PrinterApiCache.disconnected?(printer.id)).to be false
        end
      end
    end
  end

  describe '#api' do
    subject(:api) { printer.api }

    it 'is the adapter of the printer backend' do
      expect(api).to be_a(PrinterBackends::Octoprint).and have_attributes(printer:)
    end

    it 'is memoized' do
      expect(printer.api).to be api
    end

    %i[uri secret username].each do |attribute|
      it "is rebuilt when the #{attribute} changed" do
        api
        printer.public_send(:"#{attribute}=", 'changed')

        expect(printer.api).not_to be api
      end
    end

    it 'is rebuilt when the backend changed' do
      api
      printer.backend = 'repetier'

      expect { printer.api }.to raise_error(ArgumentError, 'Unknown printer backend "repetier"')
    end

    it "builds a client with the printer's URI and API key" do
      expect(api.client).to be_a(Octoprint::Client).and have_attributes(host: printer.uri, api_key: printer.secret)
    end

    it 'never hands out a client with stale credentials after they were blanked' do
      api.client
      printer.secret = ''

      expect { printer.api.client }.to raise_error(Octoprint::Exceptions::MissingCredentialsError)
      expect { printer.api.version }.to raise_error(PrinterBackends::MissingCredentials)
    end

    it 'sets the client for the current thread only' do
      client_before = Octoprint.client
      client_inside = nil
      allow(Octoprint::ServerVersion).to receive(:get) do
        client_inside = Octoprint.client
        Octoprint::ServerVersion.new(api: '0.1', server: '1.7.3', text: 'OctoPrint 1.7.3')
      end

      api.version

      expect(client_inside).to be api.client
      expect(Octoprint.client).to be client_before
    end

    [
      ['URI', { uri: '' }],
      ['URI', { uri: nil }],
      ['API key', { secret: '' }],
      ['API key', { secret: nil }]
    ].each do |missing, attributes|
      context "when the #{missing} is #{attributes.values.first.inspect}" do
        let(:printer) { build(:printer, **attributes) }

        it 'raises MissingCredentials' do
          expect { api.job_status }.to raise_error(PrinterBackends::MissingCredentials)
        end
      end
    end
  end

  describe 'using_api' do
    subject do
      printer.using_api do
        printer.api.version
      end
    end

    context 'when octoprint is connected' do
      it 'returns the octoprint version' do
        expect(subject).to eq('OctoPrint 1.7.3')
      end
    end

    context 'when octoprint is not available' do
      let(:printer) { build(:printer, :disconnected) }

      it 'raises an error' do
        expect { subject }.to raise_error(PrinterBackends::MissingCredentials)
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
          expect(PrinterApiCache.disconnected?(printer.id)).to be true
        end
      end
    end

    context 'when octoprint is misconfigured' do
      let(:printer) { build(:printer, :wrong_credentials) }

      it 'raises an error' do
        expect { subject }.to raise_error(PrinterBackends::Unauthorized)
      end
    end
  end

  describe 'version' do
    let(:printer) { create(:printer) }
    let(:redis) { MockRedis.new }

    before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

    it 'is cached as a string for 2 hours' do
      allow(Octoprint::ServerVersion).to receive(:get)
        .and_return(Octoprint::ServerVersion.new(api: '0.1', server: '1.7.3', text: 'OctoPrint 1.7.3'))

      expect(printer.version).to eq 'OctoPrint 1.7.3'
      expect(printer.version).to eq 'OctoPrint 1.7.3'
      expect(Octoprint::ServerVersion).to have_received(:get).once
      expect(described_class.find(printer.id).octoprint_version).to eq 'OctoPrint 1.7.3'
    end
  end

  describe 'current_job' do
    subject { printer.current_job }

    let(:printer) { create(:printer) }
    let(:redis) { MockRedis.new }

    before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

    it 'is the active job of the queue' do
      job = create(:printer_job, printer:, status: 'active')
      expect(subject).to eq job
    end

    it "is the printer's job otherwise", vcr: { cassette_name: 'Printer/job_status/1_4_1' } do
      expect(subject).to eq(name: 'Onix_Circle_-_Full_No_Logo.gcode', progress: 100.0)
    end

    it 'rounds the progress to one decimal' do
      allow(Octoprint::Job).to receive(:get).and_return(
        Octoprint::Job.deserialize({ state: 'Printing', job: { file: { name: 'cube.gcode' } },
                                     progress: { completion: 42.06 } })
      )
      expect(subject).to eq(name: 'cube.gcode', progress: 42.1)
    end

    it 'is nil when the printer has no job' do
      allow(Octoprint::Job).to receive(:get)
        .and_return(Octoprint::Job.deserialize({ state: 'Operational', job: { file: {} }, progress: {} }))
      expect(subject).to be_nil
    end

    it 'is nil when the printer cannot be read' do
      allow(Octoprint::Job).to receive(:get).and_raise(Octoprint::Exceptions::InternalServerError, '[500] Oops')
      expect(subject).to be_nil
    end
  end

  describe 'validations' do
    it 'requires a known backend' do
      expect(build(:printer, backend: 'repetier')).not_to be_valid
    end

    %i[uri secret].each do |attribute|
      it "requires the #{attribute} of a new printer" do
        expect(build(:printer, attribute => '')).not_to be_valid
      end

      it "does not require the #{attribute} of a printer saved before it existed" do
        printer = create(:printer, :disconnected)
        printer.name = 'Renamed'
        expect(printer).to be_valid
      end
    end
  end

  describe 'secret' do
    let(:printer) { create(:printer, secret: 'S3CR3T') }

    it 'is encrypted in the database' do
      stored = described_class.connection.select_value("SELECT secret FROM printers WHERE id = #{printer.id}")
      expect(stored).not_to include('S3CR3T')
      expect(described_class.find(printer.id).secret).to eq 'S3CR3T'
    end
  end

  describe 'octoprint_uri and octoprint_key' do
    let(:printer) { create(:printer, uri: 'http://octopi.local/', secret: 'KEY') }

    it 'mirror uri and secret, so that the previous release still works after a rollback' do
      expect(printer.reload).to have_attributes(octoprint_uri: 'http://octopi.local/', octoprint_key: 'KEY')

      printer.update!(uri: 'http://octopi2.local/', secret: 'KEY2')
      expect(printer.reload).to have_attributes(octoprint_uri: 'http://octopi2.local/', octoprint_key: 'KEY2')
    end
  end
end

RSpec.describe Printer, 'with a secret that cannot be decrypted' do
  include UnreadableSecret

  let(:printer) { make_secret_unreadable(create(:printer, name: 'Prusa MK4')) }
  let(:redis) { MockRedis.new }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  it 'raises UnreadableCredentials, a MissingCredentials error, when the secret is read' do
    expect { printer.secret }.to raise_error(PrinterBackends::UnreadableCredentials,
                                             "Stored credentials can't be read, re-enter them")
    expect(PrinterBackends::UnreadableCredentials).to be < PrinterBackends::MissingCredentials
  end

  it 'has no readable secret' do
    expect(printer.readable_secret).to be_nil
    expect(printer.api_credentials).to eq ['octoprint', 'http://10.0.1.165/', nil, nil]
  end

  it 'raises UnreadableCredentials from the API without calling the printer' do
    allow(Octoprint::Job).to receive(:get)
    expect { printer.api.job_status }.to raise_error(PrinterBackends::UnreadableCredentials)
    expect(Octoprint::Job).not_to have_received(:get)
  end

  it 'returns nil from the cached API calls, without marking the printer disconnected' do
    expect([printer.job_status, printer.version, printer.current_job]).to eq [nil, nil, nil]
    expect(PrinterApiCache.disconnected?(printer.id)).to be false
  end

  it 'is still valid and can be saved, keeping its stored secret' do
    stored = described_class.connection.select_value("SELECT secret FROM printers WHERE id = #{printer.id}")

    printer.update!(name: 'Renamed')

    expect(described_class.find(printer.id).name).to eq 'Renamed'
    expect(described_class.connection.select_value("SELECT secret FROM printers WHERE id = #{printer.id}"))
      .to eq stored
  end

  it 'can have its credentials entered again' do
    printer.update!(secret: 'NEWKEY')
    expect(described_class.find(printer.id).secret).to eq 'NEWKEY'
  end
end
