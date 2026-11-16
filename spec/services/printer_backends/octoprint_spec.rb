# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterBackends::Octoprint do
  let(:printer) { build(:printer) }
  let(:adapter) { described_class.new(printer) }

  def job(state, file: { name: 'cube.gcode' }, completion: 42.06)
    Octoprint::Job.deserialize({ state:, job: { file: }, progress: { completion: } })
  end

  it 'is OctoPrint' do
    expect(adapter.product_name).to eq 'OctoPrint'
  end

  describe 'reading the printer, from the recorded OctoPrint answers' do
    it 'reads the version', vcr: { cassette_name: 'Printer/octoprint_version/1_3_1' } do
      expect(adapter.version).to eq 'OctoPrint 1.7.3'
    end

    context 'with the job of an idle printer', vcr: { cassette_name: 'Printer/job_status/1_4_1' } do
      it { expect(adapter.job_status).to eq 'Operational' }
      it { expect(adapter.state_family).to eq PrinterStateFamily::Operational }
      it { expect(adapter.current_job).to eq(name: 'Onix_Circle_-_Full_No_Logo.gcode', progress: 100.0) }
      it { expect(adapter.print_progress).to eq(state_family: PrinterStateFamily::Operational, progress: 100.0) }
    end

    it 'raises Unauthorized when the API key is rejected',
       vcr: { cassette_name: 'Printer/using_api/when_octoprint_is_misconfigured/raises_an_error' } do
      printer.secret = '193736djdbs'
      expect { adapter.version }.to raise_error(PrinterBackends::Unauthorized, /\[403\]/)
    end

    it 'uploads a file', vcr: { cassette_name: 'Printer/upload/1_8_1' } do
      expect { adapter.upload('spec/fixture_files/test.gcode') }.not_to raise_error
    end
  end

  describe '#current_job' do
    it 'returns the file name and the unrounded completion' do
      allow(Octoprint::Job).to receive(:get).and_return(job('Printing'))
      expect(adapter.current_job).to eq(name: 'cube.gcode', progress: 42.06)
    end

    it 'is nil when there is no file' do
      allow(Octoprint::Job).to receive(:get).and_return(job('Operational', file: {}, completion: nil))
      expect(adapter.current_job).to be_nil
    end

    it 'is nil when there is no completion' do
      allow(Octoprint::Job).to receive(:get).and_return(job('Starting', completion: nil))
      expect(adapter.current_job).to be_nil
    end
  end

  describe '#print_progress' do
    it 'reads the state and the completion with a single request' do
      allow(Octoprint::Job).to receive(:get).and_return(job('Paused'))
      expect(adapter.print_progress).to eq(state_family: PrinterStateFamily::Paused, progress: 42.06)
      expect(Octoprint::Job).to have_received(:get).once
    end

    it 'has a nil progress when OctoPrint has none' do
      allow(Octoprint::Job).to receive(:get).and_return(Octoprint::Job.deserialize({ state: 'Starting', job: {} }))
      expect(adapter.print_progress).to eq(state_family: PrinterStateFamily::Printing, progress: nil)
    end
  end

  describe '#live_job' do
    it 'reads the state and the file name with a single request' do
      allow(Octoprint::Job).to receive(:get).and_return(job('Printing'))
      expect(adapter.live_job).to eq(state_family: PrinterStateFamily::Printing, file_name: 'cube.gcode')
      expect(Octoprint::Job).to have_received(:get).once
    end

    it 'has a nil file name when no job is loaded' do
      allow(Octoprint::Job).to receive(:get).and_return(Octoprint::Job.deserialize({ state: 'Operational', job: {} }))
      expect(adapter.live_job).to eq(state_family: PrinterStateFamily::Operational, file_name: nil)
    end
  end

  describe '#identify' do
    before do
      allow(Octoprint::ServerVersion).to receive(:get)
        .and_return(Octoprint::ServerVersion.new(api: '0.1', server: '1.11.2', text: 'OctoPrint 1.11.2'))
    end

    def connection(printer_profiles)
      Octoprint::Connection.new(current: { state: 'Operational' }, options: { printer_profiles: })
    end

    it "returns the default printer profile's name and the version" do
      allow(Octoprint::Connection).to receive(:get)
        .and_return(connection([{ id: 'other', name: 'Other' }, { id: '_default', name: 'Ender 3' }]))
      expect(adapter.identify).to eq(name: 'Ender 3', version: 'OctoPrint 1.11.2')
    end

    it 'has no name without a default profile' do
      allow(Octoprint::Connection).to receive(:get).and_return(connection([{ id: 'other', name: 'Other' }]))
      expect(adapter.identify).to eq(name: nil, version: 'OctoPrint 1.11.2')
    end
  end

  describe '#reported_specs' do
    def profile(id, current: false, default: false, **volume)
      { id:, name: "#{id} profile", color: 'default', model: "#{id} model", current:, default:, resource: '',
        volume: { formFactor: 'rectangular', width: 250, depth: 210, height: 220, origin: 'lowerleft', **volume },
        heatedBed: true, heatedChamber: false, axes: {},
        extruder: { count: 2, nozzleDiameter: 0.6, offsets: [[0.0, 0.0]], sharedNozzle: false } }
    end

    def stub_profiles(*profiles)
      list = Octoprint::PrinterProfiles.deserialize({ profiles: profiles.index_by { |p| p[:id] } })
      allow(Octoprint::PrinterProfiles).to receive(:list).and_return(list)
    end

    before do
      webcam = Octoprint::Settings::Webcam.from_settings({ webcam: { webcam_enabled: true, stream_url: '/webcam/' } })
      allow(Octoprint::Settings).to receive(:webcam).and_return(webcam)
    end

    it 'reads the current profile, and the webcam from the settings' do
      stub_profiles(profile('_default', default: true), profile('mk3', current: true))

      expect(adapter.reported_specs.serialize).to eq(
        'name' => 'mk3 profile', 'model' => 'mk3 model', 'bed_shape' => 'rectangular', 'build_volume_x' => 250.0,
        'build_volume_y' => 210.0, 'build_volume_z' => 220.0, 'extruders' => 2, 'nozzle_diameter' => 0.6,
        'heated_bed' => true, 'heated_chamber' => false, 'webcam' => true
      )
    end

    it 'reads the default profile when none is current' do
      stub_profiles(profile('mk3'), profile('_default', default: true))

      expect(adapter.reported_specs).to have_attributes(name: '_default profile', model: '_default model')
    end

    it 'reads the width of a circular bed as its diameter' do
      stub_profiles(profile('delta', current: true, formFactor: 'circular', width: 180, depth: 180))

      expect(adapter.reported_specs).to have_attributes(bed_shape: 'circular', build_diameter: 180.0,
                                                        build_volume_z: 220.0, build_volume_x: nil,
                                                        build_volume_y: nil)
    end

    it 'reads only the webcam without a current or default profile' do
      stub_profiles(profile('mk3'))

      expect(adapter.reported_specs.serialize).to eq('webcam' => true)
    end

    it 'reports neither firmware, brand, temperatures nor materials' do
      stub_profiles(profile('_default', default: true))

      expect(adapter.reported_specs).to have_attributes(firmware: nil, firmware_version: nil, brand: nil,
                                                        max_hotend_temp: nil, max_bed_temp: nil, materials: nil)
    end
  end

  describe '#webcam_url' do
    def webcam(enabled:, stream_url:)
      Octoprint::Settings::Webcam.from_settings({ webcam: { webcam_enabled: enabled, stream_url: } })
    end

    it 'resolves the stream URL against the OctoPrint URI, without its credentials' do
      printer.uri = 'http://admin:pw@10.0.1.165/octoprint'
      allow(Octoprint::Settings).to receive(:webcam).and_return(webcam(enabled: true, stream_url: 'webcam/'))
      expect(adapter.webcam_url).to eq 'http://10.0.1.165/octoprint/webcam/'
    end

    it 'is nil when the webcam is disabled' do
      allow(Octoprint::Settings).to receive(:webcam).and_return(webcam(enabled: false, stream_url: '/webcam/'))
      expect(adapter.webcam_url).to be_nil
    end
  end

  describe 'commands' do
    {
      pause: [[Octoprint::Job, :pause]],
      resume: [[Octoprint::Job, :resume]],
      cancel: [[Octoprint::Job, :cancel]],
      connect: [[Octoprint::Connection, :connect, { port: 'AUTO', baudrate: 0 }]],
      reconnect: [[Octoprint::Connection, :disconnect],
                  [Octoprint::Connection, :connect, { port: 'AUTO', baudrate: 0 }]]
    }.each do |command, calls|
      it "#{command} sends #{calls.map { |receiver, method| "#{receiver.name}.#{method}" }.join(' then ')}" do
        calls.each do |receiver, method, *args|
          expectation = receive(method).ordered.and_return(true)
          expectation = expectation.with(*args) if args.any?
          expect(receiver).to expectation
        end

        adapter.public_send(command)
      end
    end

    %i[pause resume cancel].each do |command|
      it "#{command} ignores the job id: OctoPrint has a single job" do
        allow(Octoprint::Job).to receive(command).and_return(true)
        adapter.public_send(command, job_id: 7)
        expect(Octoprint::Job).to have_received(command).with(no_args)
      end
    end
  end

  describe '#upload' do
    it 'selects and prints the file when asked to' do
      allow(Octoprint::Files).to receive(:upload).and_return(Octoprint::Files::OperationResult.new(done: true))
      adapter.upload('cube.gcode', print: true)
      expect(Octoprint::Files).to have_received(:upload)
        .with('cube.gcode', options: { path: nil, select: true, print: true, userdata: nil })
    end

    it 'only uploads the file by default' do
      allow(Octoprint::Files).to receive(:upload).and_return(Octoprint::Files::OperationResult.new(done: true))
      adapter.upload('cube.gcode')
      expect(Octoprint::Files).to have_received(:upload)
        .with('cube.gcode', options: { path: nil, select: nil, print: nil, userdata: nil })
    end
  end

  describe 'errors' do
    {
      Octoprint::Exceptions::ConnectionError.new('Failed to open TCP connection') => PrinterBackends::Unreachable,
      Octoprint::Exceptions::TimeoutError.new('execution expired') => PrinterBackends::Unreachable,
      Octoprint::Exceptions::AuthenticationError.new('[403] Invalid API key') => PrinterBackends::Unauthorized,
      Octoprint::Exceptions::ConflictError.new('[409] Printer is not operational') => PrinterBackends::Error
    }.each do |error, translated|
      it "raises #{error.class.name} as #{translated.name}, with the same message and the cause" do
        allow(Octoprint::Job).to receive(:get).and_raise(error)

        expect { adapter.job_status }.to raise_error(translated, error.message) { |e| expect(e.cause).to be error }
      end
    end

    [JSON::ParserError.new("unexpected token at '<html>'"), KeyError.new('key not found: :error')].each do |error|
      it "raises #{error.class.name} as it is (the answer isn't OctoPrint's)" do
        allow(Octoprint::Job).to receive(:get).and_raise(error)
        expect { adapter.job_status }.to raise_error(error.class)
      end
    end

    it 'raises MissingCredentials without calling OctoPrint when the printer has no URI' do
      printer.uri = nil
      allow(Octoprint::Job).to receive(:get)

      expect { adapter.job_status }.to raise_error(PrinterBackends::MissingCredentials, 'Missing OctoPrint credentials')
      expect(Octoprint::Job).not_to have_received(:get)
    end
  end
end
