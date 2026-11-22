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

  describe 'destroy' do
    let(:printer) { create(:printer) }
    let(:file) { create(:file_record) }
    let(:section) { Dashboard::Section.create!(title: nil, position: 0) }

    before do
      %w[enqueued active completed error].each { |status| create(:printer_job, printer:, executable: file, status:) }
      Dashboard::PrinterWidget.create!(section: section, printer:, width_units: 2, height_units: 1, position: 0)
    end

    it 'deletes its jobs, queued, under way and finished, and its dashboard widgets' do
      printer.destroy!

      expect(Printer::Job.where(printer_id: printer.id)).to be_empty
      expect(Dashboard::Widget.where(printer_id: printer.id)).to be_empty
    end

    it 'keeps the files in the library' do
      expect { printer.destroy! }.not_to(change { Library::Item.count })
    end

    it 'deletes the jobs without pushing printQueueChanged per job (Printer::Removal sends one)' do
      allow(TentaclesSchema.subscriptions).to receive(:trigger)

      printer.destroy!

      expect(TentaclesSchema.subscriptions).not_to have_received(:trigger)
    end
  end

  describe 'notify_spooler' do
    let(:printer) { create(:printer) }
    let(:redis) { instance_double(Redis, publish: 1) }

    before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

    it 'publishes the command with the printer id on the printers channel' do
      printer.notify_spooler(Printer::SpoolerCommand::AddPrinter)

      expect(redis).to have_received(:publish)
        .with('printers', { command: 'add_printer', printer_id: printer.id }.to_json)
    end
  end

  describe '#api' do
    subject(:api) { printer.api }

    it 'is the adapter of the printer backend' do
      expect(api).to be_a(Printer::Backend::Octoprint).and have_attributes(printer:)
    end

    it 'is memoized' do
      expect(printer.api).to be api
    end

    it 'is the PrusaLink adapter of a PrusaLink printer' do
      printer = build(:printer, :prusalink)
      expect(printer.api).to be_a(Printer::Backend::Prusalink).and have_attributes(printer:)
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
      expect { printer.api.version }.to raise_error(Printer::Backend::MissingCredentials)
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
          expect { api.job_status }.to raise_error(Printer::Backend::MissingCredentials)
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
        expect { subject }.to raise_error(Printer::Backend::MissingCredentials)
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
          expect(Printer::Disconnection.exists?(printer_id: printer.id)).to be true
        end

        it 'logs the error' do
          allow(Rails.logger).to receive(:error).and_call_original
          subject
          expect(Rails.logger).to have_received(:error).with(/Failed to get OctoPrint data for Printer/)
        end
      end
    end

    context 'when octoprint is misconfigured' do
      let(:printer) { build(:printer, :wrong_credentials) }

      it 'raises an error' do
        expect { subject }.to raise_error(Printer::Backend::Unauthorized)
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
      expect(described_class.find(printer.id).version).to eq 'OctoPrint 1.7.3'
    end

    it 'reads it from the printer', vcr: { cassette_name: 'Printer/version/1_3_1' } do
      expect(build(:printer).version).to eq 'OctoPrint 1.7.3'
    end
  end

  describe 'using_api caching' do
    let(:printer) { create(:printer) }
    let(:redis) { MockRedis.new }

    before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

    def call_api(cache:, &)
      printer.using_api(cache:, &)
    end

    it 'does not call the API of a disconnected printer' do
      Printer::Disconnection.create!(printer_id: printer.id)

      expect(call_api(cache: 2.hours) { raise 'called' }).to be_nil
    end

    it 'reads the cached answer but does not store one with cache: false' do
      expect(call_api(cache: false) { 'first' }).to eq 'first'
      expect(redis.keys).to be_empty

      call_api(cache: 2.hours) { 'cached' }
      expect(call_api(cache: false) { raise 'called' }).to eq 'cached'
    end

    it 'neither reads nor stores the cache with cache: nil' do
      call_api(cache: 2.hours) { 'cached' }

      expect(call_api(cache: nil) { 'fresh' }).to eq 'fresh'
    end

    it 'caches the answers under the name of the calling method' do
      allow(Octoprint::ServerVersion).to receive(:get)
        .and_return(Octoprint::ServerVersion.new(api: '0.1', server: '1.7.3', text: 'OctoPrint 1.7.3'))
      allow(Octoprint::Job).to receive(:get).and_return(Octoprint::Job.deserialize({ state: 'Operational', job: {} }))

      expect([printer.version, printer.job_status]).to eq ['OctoPrint 1.7.3', 'Operational']
      expect(redis.keys).to eq ["printer_api_#{printer.id}_Printer#version"]
    end

    it 'does not cache the answers of an unsaved printer' do
      expect(build(:printer).using_api(cache: 2.hours) { 'answer' }).to eq 'answer'
      expect(redis.keys).to be_empty
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

    it 'accepts PrusaLink printers' do
      expect(build(:printer, :prusalink)).to be_valid
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
end

RSpec.describe Printer, 'with a secret that cannot be decrypted' do
  include UnreadableSecret

  let(:printer) { make_secret_unreadable(create(:printer, name: 'Prusa MK4')) }
  let(:redis) { MockRedis.new }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  it 'raises UnreadableCredentials, a MissingCredentials error, when the secret is read' do
    expect { printer.secret }.to raise_error(Printer::Backend::UnreadableCredentials,
                                             "Stored credentials can't be read, re-enter them")
    expect(Printer::Backend::UnreadableCredentials).to be < Printer::Backend::MissingCredentials
  end

  it 'has no readable secret' do
    expect(printer.readable_secret).to be_nil
    expect(printer.api_credentials).to eq ['octoprint', 'http://10.0.1.165/', nil, nil]
  end

  it 'raises UnreadableCredentials from the API without calling the printer' do
    allow(Octoprint::Job).to receive(:get)
    expect { printer.api.job_status }.to raise_error(Printer::Backend::UnreadableCredentials)
    expect(Octoprint::Job).not_to have_received(:get)
  end

  it 'returns nil from the cached API calls, without marking the printer disconnected' do
    expect([printer.job_status, printer.version, printer.current_job]).to eq [nil, nil, nil]
    expect(Printer::Disconnection.exists?(printer_id: printer.id)).to be false
  end

  it 'is still valid and can be saved, keeping its stored secret' do
    stored = described_class.connection.select_value("SELECT secret FROM printers WHERE id = #{printer.id}")

    printer.update!(name: 'Renamed')

    expect(described_class.find(printer.id).name).to eq 'Renamed'
    expect(described_class.connection.select_value("SELECT secret FROM printers WHERE id = #{printer.id}"))
      .to eq stored
  end

  it 'can be saved through every save path' do
    expect(printer.save).to be true
    expect(printer.update(name: 'Renamed')).to be true
    expect(printer.update_attribute(:favorite, true)).to be true # rubocop:disable Rails/SkipsModelValidations
    expect(make_secret_unreadable(printer).toggle!(:favorite)).to be true # rubocop:disable Rails/SkipsModelValidations
    expect(described_class.find(printer.id)).to have_attributes(name: 'Renamed', favorite: false)
  end

  it 'can have its credentials entered again' do
    printer.update!(secret: 'NEWKEY')
    expect(described_class.find(printer.id).secret).to eq 'NEWKEY'
  end
end
