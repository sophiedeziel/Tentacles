# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterBackends::Prusalink do
  let(:printer) { build(:printer, :prusalink) }
  let(:adapter) { described_class.new(printer) }

  def status(state, job: nil)
    Prusalink::Status.deserialize({ printer: { state:, temp_nozzle: 215.0, target_nozzle: 215.0 }, job: })
  end

  def job(id: 7, progress: 42.06, file: { name: 'CUBE~1.BGC', display_name: 'cube.bgcode' })
    Prusalink::Job.deserialize({ id:, state: 'PRINTING', progress:, file: })
  end

  it 'is named PrusaLink, with a password' do
    expect(adapter).to have_attributes(product_name: 'PrusaLink', secret_name: 'password', connects_on_its_own?: true)
  end

  describe '#client' do
    it "is built from the printer's URI, username and password, with short timeouts" do
      expect(adapter.client).to have_attributes(host: 'http://prusa-mk4.local', username: 'maker',
                                                password: 'printer-password', open_timeout: 2, timeout: 5)
    end

    it 'uses the default username when the printer has none' do
      printer.username = ''
      expect(adapter.client.username).to eq 'maker'
    end

    it "uses the printer's username" do
      printer.username = 'admin'
      expect(adapter.client.username).to eq 'admin'
    end

    it 'sends every request with its own client, leaving the thread client alone' do
      clients = []
      allow(Prusalink::Status).to receive(:get) {
        clients << Prusalink.client
        status('IDLE')
      }

      adapter.job_status
      expect(clients).to eq [adapter.client]
      expect(Prusalink.client).to be_nil
    end
  end

  describe '#current_job' do
    it 'returns the display name and the unrounded progress' do
      allow(Prusalink::Job).to receive(:get).and_return(job)
      expect(adapter.current_job).to eq(name: 'cube.bgcode', progress: 42.06)
    end

    it 'falls back to the file name' do
      allow(Prusalink::Job).to receive(:get).and_return(job(file: { name: 'cube.gcode' }))
      expect(adapter.current_job).to eq(name: 'cube.gcode', progress: 42.06)
    end

    it 'is nil when the printer is idle' do
      allow(Prusalink::Job).to receive(:get).and_return(nil)
      expect(adapter.current_job).to be_nil
    end

    it 'is nil when there is no progress' do
      allow(Prusalink::Job).to receive(:get).and_return(job(progress: nil))
      expect(adapter.current_job).to be_nil
    end
  end

  describe '#job_status' do
    it "returns PrusaLink's state, capitalized" do
      allow(Prusalink::Status).to receive(:get).and_return(status('ATTENTION'))
      expect(adapter.job_status).to eq 'Attention'
    end
  end

  describe '#state_family' do
    it 'maps the state' do
      allow(Prusalink::Status).to receive(:get).and_return(status('BUSY'))
      expect(adapter.state_family).to eq PrinterStateFamily::Operational
    end

    it 'is PAUSED when the printer needs attention during a job' do
      allow(Prusalink::Status).to receive(:get).and_return(status('ATTENTION', job: { id: 7, progress: 12.0 }))
      expect(adapter.state_family).to eq PrinterStateFamily::Paused
    end

    it 'is ERROR when the printer needs attention without a job' do
      allow(Prusalink::Status).to receive(:get).and_return(status('ATTENTION'))
      expect(adapter.state_family).to eq PrinterStateFamily::Error
    end

    it 'raises when PrusaLink answers without a status' do
      allow(Prusalink::Status).to receive(:get).and_return(nil)
      expect { adapter.state_family }.to raise_error(PrinterBackends::Error, 'PrusaLink answered without a status')
    end
  end

  describe '#print_progress' do
    it 'reads the state and the progress with a single request' do
      allow(Prusalink::Status).to receive(:get).and_return(status('PRINTING', job: { id: 7, progress: 42.0 }))
      expect(adapter.print_progress).to eq(state_family: PrinterStateFamily::Printing, progress: 42.0)
      expect(Prusalink::Status).to have_received(:get).once
    end

    it 'has a nil progress when there is no job' do
      allow(Prusalink::Status).to receive(:get).and_return(status('IDLE'))
      expect(adapter.print_progress).to eq(state_family: PrinterStateFamily::Operational, progress: nil)
    end
  end

  describe '#live_job' do
    it 'reads the state, then the display name and id of the job' do
      allow(Prusalink::Status).to receive(:get).and_return(status('PRINTING', job: { id: 7, progress: 42.0 }))
      allow(Prusalink::Job).to receive(:get).and_return(job)
      expect(adapter.live_job)
        .to eq(state_family: PrinterStateFamily::Printing, file_name: 'cube.bgcode', job_id: 7)
    end

    it 'falls back to the file name, like the monitor' do
      allow(Prusalink::Status).to receive(:get).and_return(status('PAUSED', job: { id: 7, progress: 42.0 }))
      allow(Prusalink::Job).to receive(:get).and_return(job(file: { name: 'cube.gcode' }))
      expect(adapter.live_job[:file_name]).to eq 'cube.gcode'
    end

    it 'reads no job when the printer is idle' do
      allow(Prusalink::Status).to receive(:get).and_return(status('IDLE'))
      allow(Prusalink::Job).to receive(:get)
      expect(adapter.live_job).to eq(state_family: PrinterStateFamily::Operational, file_name: nil, job_id: nil)
      expect(Prusalink::Job).not_to have_received(:get)
    end
  end

  describe '#version' do
    it 'names PrusaLink and the firmware' do
      allow(Prusalink::ServerVersion).to receive(:get)
        .and_return(Prusalink::ServerVersion.new(version: '2.1.2', firmware: '6.2.0+8899'))
      expect(adapter.version).to eq 'PrusaLink 2.1.2 (firmware 6.2.0+8899)'
    end

    it 'leaves out an unknown firmware' do
      allow(Prusalink::ServerVersion).to receive(:get).and_return(Prusalink::ServerVersion.new(version: '2.1.2'))
      expect(adapter.version).to eq 'PrusaLink 2.1.2'
    end
  end

  describe '#identify' do
    before do
      allow(Prusalink::ServerVersion).to receive(:get)
        .and_return(Prusalink::ServerVersion.new(version: '2.1.2', firmware: '6.2.0+8899'))
    end

    it "returns the printer's name and the version" do
      allow(Prusalink::Info).to receive(:get).and_return(Prusalink::Info.new(name: 'Workshop MK4'))
      expect(adapter.identify).to eq(name: 'Workshop MK4', version: 'PrusaLink 2.1.2 (firmware 6.2.0+8899)')
    end

    it 'falls back to the host when the printer has no name' do
      allow(Prusalink::Info).to receive(:get).and_return(Prusalink::Info.new(name: ''))
      expect(adapter.identify).to eq(name: 'prusa-mk4.local', version: 'PrusaLink 2.1.2 (firmware 6.2.0+8899)')
    end

    it 'raises Unauthorized when the password is rejected' do
      allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::AuthenticationError,
                                                        '[401] Unauthorized')
      expect { adapter.identify }.to raise_error(PrinterBackends::Unauthorized, '[401] Unauthorized')
    end
  end

  describe '#reported_specs' do
    def stub_server(printer: nil, firmware: '6.2.0+8899', info: Prusalink::Info.new(name: 'XL', nozzle_diameter: 0.6))
      allow(Prusalink::Info).to receive(:get).and_return(info)
      allow(Prusalink::ServerVersion).to receive(:get)
        .and_return(Prusalink::ServerVersion.new(version: '2.1.2', printer:, firmware:))
    end

    it 'reads the name and nozzle from the info, the firmware version from the server version' do
      stub_server

      expect(adapter.reported_specs.serialize).to eq(
        'name' => 'XL', 'firmware' => 'prusa_firmware', 'firmware_version' => '6.2.0+8899', 'nozzle_diameter' => 0.6
      )
    end

    it 'reads the model when the server names it' do
      stub_server(printer: 'MK4')

      expect(adapter.reported_specs.model).to eq 'MK4'
    end

    it 'has no model when the server sends a version instead' do
      stub_server(printer: '1.0.0')

      expect(adapter.reported_specs.model).to be_nil
    end

    it 'is always Prusa firmware, even without a firmware version' do
      stub_server(firmware: nil, info: nil)

      expect(adapter.reported_specs.serialize).to eq('firmware' => 'prusa_firmware')
    end
  end

  describe '.readable_model' do
    it 'keeps a model name' do
      expect(%w[MK4 XL MINI I3MK3S].map { described_class.readable_model(it) }).to eq %w[MK4 XL MINI I3MK3S]
    end

    it 'drops versions and blanks' do
      expect(['1.0.0', '6.2.0+8899', '2.1.2-rc1', '', ' ', nil].map { described_class.readable_model(it) })
        .to all(be_nil)
    end
  end

  it 'has no webcam' do
    expect(adapter.webcam_url).to be_nil
  end

  describe 'job commands' do
    { pause: :pause, resume: :resume, cancel: :stop }.each do |command, gem_method|
      describe "##{command}" do
        before { allow(Prusalink::Job).to receive(gem_method).and_return(true) }

        it "sends #{gem_method} with the id of the current job" do
          allow(Prusalink::Job).to receive(:get).and_return(job(id: 42))
          adapter.public_send(command)
          expect(Prusalink::Job).to have_received(gem_method).with(42)
        end

        it "sends #{gem_method} to the given job, without reading it" do
          allow(Prusalink::Job).to receive(:get)
          adapter.public_send(command, job_id: 7)
          expect(Prusalink::Job).to have_received(gem_method).with(7)
          expect(Prusalink::Job).not_to have_received(:get)
        end

        it 'raises NoJob when there is no job' do
          allow(Prusalink::Job).to receive(:get).and_return(nil)
          expect { adapter.public_send(command) }.to raise_error(PrinterBackends::NoJob, 'No job under way')
          expect(Prusalink::Job).not_to have_received(gem_method)
        end
      end
    end

    it 'translates a refused command' do
      allow(Prusalink::Job).to receive(:get).and_return(job)
      allow(Prusalink::Job).to receive(:pause).and_raise(Prusalink::Exceptions::ConflictError, '[409] Conflict')
      expect { adapter.pause }.to raise_error(PrinterBackends::Error, '[409] Conflict')
    end
  end

  %i[connect reconnect].each do |command|
    it "refuses to #{command}: PrusaLink connects on its own" do
      expect { adapter.public_send(command) }
        .to raise_error(PrinterBackends::Error, 'PrusaLink printers connect on their own')
    end
  end

  describe '#upload' do
    let(:path) { 'tmp/cube.gcode' }
    let(:usb) { { name: 'usb', type: 'USB', path: '/usb', available: true, read_only: false } }
    let(:storages) { [usb] }

    def storage(attributes)
      Prusalink::Storage.deserialize(attributes)
    end

    before do
      allow(Prusalink::Storage).to receive(:list) { storages.map { |attributes| storage(attributes) } }
      allow(Prusalink::Files).to receive(:upload).and_return(true)
    end

    it 'uploads the file to the root of the storage, replacing a file of the same name' do
      adapter.upload(path)
      expect(Prusalink::Files).to have_received(:upload)
        .with(path, storage: '/usb', path: 'cube.gcode', print_after_upload: false, overwrite: true)
    end

    it 'prints the file after the upload when asked to' do
      adapter.upload(path, print: true)
      expect(Prusalink::Files).to have_received(:upload)
        .with(path, storage: '/usb', path: 'cube.gcode', print_after_upload: true, overwrite: true)
    end

    it 'uploads binary G-code unchanged' do
      adapter.upload('tmp/cube.bgcode', print: true)
      expect(Prusalink::Files).to have_received(:upload)
        .with('tmp/cube.bgcode', storage: '/usb', path: 'cube.bgcode', print_after_upload: true, overwrite: true)
    end

    context 'with several storages' do
      let(:storages) do
        [
          { name: 'sd', type: 'SDCARD', path: '/sd', available: false, read_only: false },
          { name: 'firmware', type: 'LOCAL', path: '/firmware', available: true, read_only: true },
          { name: 'local', type: 'LOCAL', path: '/local', available: true, read_only: false },
          usb
        ]
      end

      it 'picks the first available storage that is not read only' do
        adapter.upload(path)
        expect(Prusalink::Files).to have_received(:upload).with(path, hash_including(storage: '/local'))
      end
    end

    [
      [],
      [{ name: 'usb', type: 'USB', path: '/usb', available: false }],
      [{ name: 'usb', type: 'USB', path: '/usb', available: true, read_only: true }]
    ].each do |list|
      context "with storages #{list}" do
        let(:storages) { list }

        it 'raises a readable error without uploading' do
          printer.name = 'Prusa MK4'
          expect { adapter.upload(path) }
            .to raise_error(PrinterBackends::Error, 'Prusa MK4 has no writable storage. Insert a USB drive')
          expect(Prusalink::Files).not_to have_received(:upload)
        end
      end
    end

    it 'uploads with its own client and long timeouts, and lists the storages with the API client' do
      clients = {}
      allow(Prusalink::Storage).to receive(:list) {
        clients[:list] = Prusalink.client
        [storage(usb)]
      }
      allow(Prusalink::Files).to receive(:upload) { clients[:upload] = Prusalink.client }

      adapter.upload(path)

      expect(clients[:list]).to be adapter.client
      expect(clients[:upload]).to have_attributes(host: 'http://prusa-mk4.local', username: 'maker',
                                                  password: 'printer-password', open_timeout: 5, timeout: 120)
      expect(Prusalink.client).to be_nil
    end

    it 'translates the errors of the upload' do
      allow(Prusalink::Files).to receive(:upload).and_raise(Prusalink::Exceptions::ConflictError, '[409] Conflict')
      expect { adapter.upload(path) }.to raise_error(PrinterBackends::Error, '[409] Conflict')
    end

    context 'with the HTTP answers of the printer' do
      include WebMock::API

      around { |example| VCR.turned_off { example.run } }

      let(:file) { Rails.root.join('spec/fixture_files/test.gcode').to_s }

      before do
        allow(Prusalink::Storage).to receive(:list).and_call_original
        allow(Prusalink::Files).to receive(:upload).and_call_original
        stub_request(:get, 'http://prusa-mk4.local/api/v1/storage')
          .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                     body: { storage_list: [usb] }.to_json)
        # The gem's digest middleware fetches the challenge with a HEAD before streaming a file
        stub_request(:head, 'http://prusa-mk4.local/api/v1/files/usb/test.gcode').to_return(status: 404)
      end

      it 'sends the file with the Print-After-Upload and Overwrite headers' do
        upload = stub_request(:put, 'http://prusa-mk4.local/api/v1/files/usb/test.gcode')
                 .with(body: File.binread(file),
                       headers: { 'Content-Type' => 'application/octet-stream', 'Print-After-Upload' => '?1',
                                  'Overwrite' => '?1' })
                 .to_return(status: 201)

        adapter.upload(file, print: true)
        assert_requested(upload)
      end

      it 'raises Unreachable when the upload times out' do
        stub_request(:put, 'http://prusa-mk4.local/api/v1/files/usb/test.gcode').to_timeout
        expect { adapter.upload(file) }.to raise_error(PrinterBackends::Unreachable)
      end
    end
  end

  describe 'error translation' do
    {
      Prusalink::Exceptions::ConnectionError.new('Failed to open TCP connection') =>
        PrinterBackends::Unreachable,
      Prusalink::Exceptions::TimeoutError.new('execution expired') => PrinterBackends::Unreachable,
      Prusalink::Exceptions::AuthenticationError.new('[401] Unauthorized') => PrinterBackends::Unauthorized,
      Prusalink::Exceptions::InvalidResponseError.new('The printer answered with invalid JSON') =>
        PrinterBackends::Error
    }.each do |error, translated|
      it "raises #{error.class.name.demodulize} as #{translated} with the same message" do
        allow(Prusalink::Status).to receive(:get).and_raise(error)
        expect { adapter.job_status }.to raise_error(translated, error.message)
      end
    end

    [{ uri: nil }, { secret: nil }, { secret: '' }].each do |attributes|
      it "raises MissingCredentials without contacting the printer (#{attributes})" do
        allow(Prusalink::Status).to receive(:get)
        printer.assign_attributes(attributes)

        expect { adapter.job_status }
          .to raise_error(PrinterBackends::MissingCredentials, 'Missing PrusaLink credentials')
        expect(Prusalink::Status).not_to have_received(:get)
      end
    end

    context 'with the HTTP answers of the printer' do
      include WebMock::API

      around { |example| VCR.turned_off { example.run } }

      let(:request) { stub_request(:get, 'http://prusa-mk4.local/api/v1/status') }

      it 'raises Unauthorized when PrusaLink rejects the password' do
        request.to_return(status: 401, body: 'Unauthorized')
        expect { adapter.job_status }.to raise_error(PrinterBackends::Unauthorized, '[401] Unauthorized')
      end

      it 'raises Unreachable when the connection is refused' do
        request.to_raise(Errno::ECONNREFUSED)
        expect { adapter.job_status }.to raise_error(PrinterBackends::Unreachable)
      end

      it 'raises Unreachable on a timeout' do
        request.to_timeout
        expect { adapter.job_status }.to raise_error(PrinterBackends::Unreachable)
      end
    end
  end
end
