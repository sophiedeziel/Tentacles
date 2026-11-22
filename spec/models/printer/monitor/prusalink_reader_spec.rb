# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Monitor::PrusalinkReader do
  let(:printer) { create(:printer, :prusalink) }
  let(:reader) { described_class.new(printer:) }

  let(:state) { 'PRINTING' }
  let(:job) { { id: 7, progress: 42.0, time_remaining: 600, time_printing: 1200 } }
  let(:temperatures) { { temp_nozzle: 214.6, target_nozzle: 215.0, temp_bed: 59.8, target_bed: 60.0 } }

  def status(state:, job:, temperatures: {})
    Prusalink::Status.deserialize({ printer: { state:, **temperatures }, job: job&.dup })
  end

  def prusalink_job(id:, file: { name: 'CUBE~1.BGC', display_name: 'cube.bgcode' })
    Prusalink::Job.deserialize({ id:, state: 'PRINTING', progress: 42.0, file: })
  end

  before do
    allow(Prusalink::Status).to receive(:get) { status(state:, job:, temperatures:) }
    allow(Prusalink::Job).to receive(:get) { prusalink_job(id: 7) }
  end

  describe '#status_attributes' do
    subject(:attributes) { reader.status_attributes }

    it 'reads the state, the job and the temperatures' do
      expect(attributes).to eq(
        state_family: Printer::StateFamily::Printing, state_text: 'Printing', error_text: nil,
        file_name: 'cube.bgcode', progress: 42.0, print_time_left: 600,
        hotend: Printer::Status::Temperature.new(actual: 214.6, target: 215.0),
        bed: Printer::Status::Temperature.new(actual: 59.8, target: 60.0)
      )
    end

    it 'builds a valid snapshot' do
      expect(Printer::Status.new(printer_id: printer.id, **attributes)).to be_a(Printer::Status)
    end

    # Every row of the state table (see Printer::StateFamily.for_prusalink)
    [
      ['PRINTING', true, Printer::StateFamily::Printing, 'Printing'],
      ['PAUSED', true, Printer::StateFamily::Paused, 'Paused'],
      ['ATTENTION', true, Printer::StateFamily::Paused, 'Attention'],
      ['ATTENTION', false, Printer::StateFamily::Error, 'Attention'],
      ['IDLE', false, Printer::StateFamily::Operational, 'Idle'],
      ['READY', false, Printer::StateFamily::Operational, 'Ready'],
      ['FINISHED', false, Printer::StateFamily::Operational, 'Finished'],
      ['STOPPED', false, Printer::StateFamily::Operational, 'Stopped'],
      ['BUSY', false, Printer::StateFamily::Operational, 'Busy'],
      ['ERROR', false, Printer::StateFamily::Error, 'Error']
    ].each do |prusalink_state, with_job, family, text|
      context "when PrusaLink is #{prusalink_state} #{with_job ? 'with' : 'without'} a job" do
        let(:state) { prusalink_state }
        let(:job) { with_job ? super() : nil }

        it { expect(attributes).to include(state_family: family, state_text: text) }
      end
    end

    context 'with an unknown state' do
      let(:state) { 'TRANSMOGRIFYING' }

      it 'reports it as OFFLINE, keeping the word' do
        expect(attributes).to include(state_family: Printer::StateFamily::Offline, state_text: 'Transmogrifying')
      end
    end

    context 'when the printer is idle' do
      let(:state) { 'IDLE' }
      let(:job) { nil }
      let(:temperatures) { { temp_nozzle: 24.0, target_nozzle: 0.0, temp_bed: 23.5, target_bed: 0.0 } }

      it 'has no job and does not read it' do
        expect(attributes).to include(state_family: Printer::StateFamily::Operational, file_name: nil, progress: nil,
                                      print_time_left: nil)
        expect(Prusalink::Job).not_to have_received(:get)
      end

      it 'still reads the temperatures' do
        expect(attributes).to include(hotend: Printer::Status::Temperature.new(actual: 24.0, target: 0.0),
                                      bed: Printer::Status::Temperature.new(actual: 23.5, target: 0.0))
      end
    end

    context 'without temperatures' do
      let(:temperatures) { {} }

      it { expect(attributes).to include(hotend: nil, bed: nil) }
    end

    it 'falls back to the file name when there is no display name' do
      allow(Prusalink::Job).to receive(:get).and_return(prusalink_job(id: 7, file: { name: 'cube.gcode' }))
      expect(attributes[:file_name]).to eq 'cube.gcode'
    end

    it 'sends a single Status request' do
      attributes
      expect(Prusalink::Status).to have_received(:get).once
    end

    it "uses the printer's own client" do
      clients = []
      allow(Prusalink::Status).to receive(:get) {
        clients << Prusalink.client
        status(state:, job:)
      }
      attributes
      expect(clients).to eq [T.cast(printer.api, Printer::Backend::Prusalink).client]
    end

    context 'when the printer is unreachable' do
      before { allow(Prusalink::Status).to receive(:get).and_raise(Prusalink::Exceptions::TimeoutError, 'timed out') }

      it { expect { attributes }.to raise_error(Printer::Backend::Unreachable, 'timed out') }
    end

    context 'when the password is rejected' do
      before do
        allow(Prusalink::Status).to receive(:get).and_raise(Prusalink::Exceptions::AuthenticationError, '[401] Nope')
      end

      it { expect { attributes }.to raise_error(Printer::Backend::Unauthorized, '[401] Nope') }
    end

    context 'when the printer has no password' do
      let(:printer) { create(:printer, :prusalink, :unvalidated, secret: nil) }

      it 'raises MissingCredentials without contacting the printer' do
        expect { attributes }.to raise_error(Printer::Backend::MissingCredentials)
        expect(Prusalink::Status).not_to have_received(:get)
      end
    end

    context 'when PrusaLink answers without a status' do
      before { allow(Prusalink::Status).to receive(:get).and_return(nil) }

      it { expect { attributes }.to raise_error(Printer::Backend::Error, 'PrusaLink answered without a status') }
    end
  end

  describe 'reading the file name' do
    it 'reads the job once per job, not on every tick' do
      3.times { reader.status_attributes }

      expect(Prusalink::Status).to have_received(:get).exactly(3).times
      expect(Prusalink::Job).to have_received(:get).once
    end

    it 'reads the job again when another job starts' do
      2.times { reader.status_attributes }
      allow(Prusalink::Status).to receive(:get) { status(state:, job: job.merge(id: 8)) }
      allow(Prusalink::Job).to receive(:get) { prusalink_job(id: 8, file: { name: 'benchy.gcode' }) }
      2.times { reader.status_attributes }

      expect(reader.status_attributes[:file_name]).to eq 'benchy.gcode'
      expect(Prusalink::Job).to have_received(:get).twice
    end

    it 'forgets the job once the printer is idle' do
      reader.status_attributes
      allow(Prusalink::Status).to receive(:get) { status(state: 'IDLE', job: nil) }
      reader.status_attributes
      allow(Prusalink::Status).to receive(:get) { status(state:, job:) }

      expect(reader.status_attributes[:file_name]).to eq 'cube.bgcode'
      expect(Prusalink::Job).to have_received(:get).twice
    end

    it 'tries again on the next tick when the job ended in the meantime' do
      allow(Prusalink::Job).to receive(:get).and_return(nil)
      expect(reader.status_attributes[:file_name]).to be_nil

      allow(Prusalink::Job).to receive(:get) { prusalink_job(id: 7) }
      expect(reader.status_attributes[:file_name]).to eq 'cube.bgcode'
    end

    context 'when PrusaLink answers the job with invalid JSON (XL firmware, deleted file)' do
      before do
        allow(Prusalink::Job).to receive(:get)
          .and_raise(Prusalink::Exceptions::InvalidResponseError, 'The printer answered with invalid JSON')
        allow(Rails.logger).to receive(:error)
      end

      it 'goes on without the file name, and does not ask again for that job' do
        2.times { expect(reader.status_attributes).to include(state_family: Printer::StateFamily::Printing, file_name: nil) }
        expect(Prusalink::Job).to have_received(:get).once
        expect(Rails.logger).to have_received(:error).with(/Failed to read the job/).once
      end
    end
  end

  describe '#camera' do
    it 'is disabled' do
      expect(reader.camera).to eq Printer::Status::Camera.new(enabled: false)
    end
  end
end
