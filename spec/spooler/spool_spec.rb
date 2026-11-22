# frozen_string_literal: true

require 'rails_helper'
require 'spooler'

RSpec.describe Spooler::Spool do
  let(:printer) { create(:printer) }
  let(:spool) { described_class.new(printer) }

  # Spool.new starts its operations thread right away: it only spins while the spool isn't active
  after { spool.instance_variable_get(:@thread).kill.join }

  describe '#working?' do
    subject { spool.working? }

    it { is_expected.to eq false }
  end

  describe 'running a print job' do
    let(:printer_job) { create(:printer_job, printer:) }
    let(:operation) { Spooler::Print.new(printer, printer_job) }
    let(:job_status_at_each_poll) { [] }

    before do
      allow(TentaclesSchema).to receive(:subscriptions)
        .and_return(instance_double(GraphQL::Subscriptions, trigger: nil))
      allow(UploadFilesToPrintersJob).to receive(:perform_now)
      allow(operation).to receive(:sleep)
      allow(operation).to receive(:log)

      states = %w[Printing Paused Paused Printing Operational]
      allow(Octoprint::Job).to receive(:get) do
        state = states.shift
        job_status_at_each_poll << [state, printer_job.reload.status]
        Octoprint::Job.deserialize({ state:, job: { file: { name: 'cube.gcode' } }, progress: { completion: 50.0 } })
      end

      # What the operations loop does with the next job
      spool.instance_variable_set(:@current_operation, operation)
      spool.send(:start_and_monitor)
      spool.instance_variable_set(:@current_operation, nil)
    end

    it 'keeps the job active through a pause and a resume, until the print finishes' do
      expect(job_status_at_each_poll).to eq [
        %w[Printing active], %w[Paused active], %w[Paused active], %w[Printing active], %w[Operational active]
      ]
    end

    it 'completes the job once the print is over' do
      expect(printer_job.reload.status).to eq 'completed'
    end
  end

  describe 'running a print job on a PrusaLink printer' do
    let(:printer) { create(:printer, :prusalink, name: 'Prusa MK4') }
    let(:printer_job) { create(:printer_job, printer:) }
    let(:operation) { Spooler::Print.new(printer, printer_job) }
    let(:subscriptions) { instance_double(GraphQL::Subscriptions, trigger: nil) }
    let(:usb) { Prusalink::Storage.deserialize({ name: 'usb', type: 'USB', path: '/usb', available: true }) }
    # What PrusaLink reports at each poll, and the job's status then
    let(:polls) { [] }

    # PrusaLink reports each `[state, progress]` in turn. A state without progress has no job.
    def stub_states(states)
      allow(Prusalink::Status).to receive(:get) do
        state, progress = states.shift
        polls << [state, printer_job.reload.status]
        Prusalink::Status.deserialize({ printer: { state: }, job: progress && { id: 7, progress: } })
      end
    end

    # What the operations loop does with the next job
    def run_job(*states)
      stub_states(states)
      spool.instance_variable_set(:@current_operation, operation)
      spool.send(:start_and_monitor)
      spool.instance_variable_set(:@current_operation, nil)
    end

    before do
      allow(TentaclesSchema).to receive(:subscriptions).and_return(subscriptions)
      allow(Prusalink::Storage).to receive(:list).and_return([usb])
      allow(Prusalink::Files).to receive(:upload).and_return(true)
      allow(operation).to receive(:sleep)
      allow(operation).to receive(:log)
    end

    it 'uploads the file to the USB drive and prints it' do
      run_job(['PRINTING', 10.0], ['FINISHED'])
      expect(Prusalink::Files).to have_received(:upload).with(
        Rails.root.join('tmp/test.gcode').to_s,
        storage: '/usb', path: 'test.gcode', print_after_upload: true, overwrite: true
      )
    end

    it 'completes the job once the print is finished, tracking its progress' do
      run_job(['IDLE'], ['BUSY'], ['PRINTING', 10.0], ['PRINTING', 62.4], ['FINISHED'])

      expect(polls).to eq [%w[IDLE active], %w[BUSY active], %w[PRINTING active], %w[PRINTING active],
                           %w[FINISHED active]]
      expect(printer_job.reload).to have_attributes(status: 'completed', progress: 63)
      # Once per new status (active, completed), not per progress write
      expect(subscriptions).to have_received(:trigger).with(:print_queue_changed, {}, printer).twice
    end

    it 'keeps the job active through a pause and a resume, until the print finishes' do
      run_job(['PRINTING', 10.0], ['PAUSED', 12.0], ['ATTENTION', 12.0], ['PAUSED', 12.0], ['PRINTING', 13.0],
              ['FINISHED'])

      expect(polls.map(&:last)).to all(eq 'active')
      expect(polls.map(&:first)).to eq %w[PRINTING PAUSED ATTENTION PAUSED PRINTING FINISHED]
      expect(printer_job.reload.status).to eq 'completed'
    end

    it 'completes the job once a cancelled print is stopped' do
      run_job(['PRINTING', 10.0], ['STOPPED'])
      expect(printer_job.reload.status).to eq 'completed'
    end

    context 'when the printer has no USB drive' do
      before { allow(Prusalink::Storage).to receive(:list).and_return([]) }

      it 'marks the job as an error, without monitoring the print' do
        run_job

        expect(printer_job.reload.status).to eq 'error'
        expect(polls).to be_empty
        expect(operation).to have_received(:log)
          .with(/Could not start the print: Printer::Backend::Error: Prusa MK4 has no writable storage/)
        expect(subscriptions).to have_received(:trigger)
          .with(:printer_subscription, { id: printer.id }, {}).at_least(:twice)
        expect(subscriptions).to have_received(:trigger).with(:print_queue_changed, {}, printer).twice
      end
    end

    context 'when the upload times out' do
      before do
        allow(Prusalink::Files).to receive(:upload).and_raise(Prusalink::Exceptions::TimeoutError, 'Net::ReadTimeout')
      end

      it 'marks the job as an error' do
        run_job
        expect(printer_job.reload.status).to eq 'error'
        expect(operation).to have_received(:log).with(/Printer::Backend::Unreachable: Net::ReadTimeout/)
      end
    end
  end
end
