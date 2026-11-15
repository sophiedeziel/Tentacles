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

  it 'does not upload yet' do
    expect { adapter.upload('spec/fixture_files/test.gcode') }.to raise_error(NotImplementedError, /not supported yet/)
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
