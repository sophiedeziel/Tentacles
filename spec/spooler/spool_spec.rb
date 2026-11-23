# frozen_string_literal: true

require 'rails_helper'
require 'spooler'

RSpec.describe Spooler::Spool do
  let(:printer) { create(:printer) }
  let(:spool) { described_class.new(printer) }

  # Spool.new starts its operations thread right away: it only spins while the spool isn't active
  after { spool.discard }

  # Starts the spool and waits for its thread to be in its loop, past the adoption of a copy under way (the global
  # queue on): the examples then run the spool's steps themselves. The thread finds no job meanwhile.
  def start_spool
    in_loop = Thread::Queue.new
    # The loop asks for a job over and over: one signal is enough
    allow(printer).to receive(:next_job) do
      in_loop.push(true) if in_loop.empty?
      nil
    end
    spool.resume
    in_loop.pop(timeout: 5) || raise('The spool did not reach its loop within 5 s')
  end

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

  describe 'running a copy of a global queue entry' do
    let(:printer) { create(:printer, name: 'Ender 3') }
    let(:copy) { create(:printer_job, :copy, printer:) }
    let(:operation) { Spooler::Print.new(printer, copy) }
    let(:dispatch_request) { instance_spy(PrintQueue::DispatchRequest, save: true) }
    # The copy's status at each poll, and whether the spool looked busy when PrintEnd asked for a dispatch pass
    let(:polls) { [] }
    let(:working_at_dispatch) { [] }

    before do
      allow(PrintQueue).to receive(:enabled?).and_return(true)
      allow(TentaclesSchema).to receive(:subscriptions)
        .and_return(instance_double(GraphQL::Subscriptions, trigger: nil))
      start_spool
      allow(PrintQueue::DispatchRequest).to receive(:new).and_return(dispatch_request)
      allow(dispatch_request).to receive(:save) { working_at_dispatch << spool.working? }
      allow(UploadFilesToPrintersJob).to receive(:perform_now)
      allow(operation).to receive(:sleep)
      allow(operation).to receive(:log)
      allow(spool).to receive(:build_operation).and_return(operation)
      %w[PrintStart PrintProgress PrintEnd].each do |event|
        allow(PrintQueue.const_get(event)).to receive(:new).and_call_original
      end
    end

    # The printer reports each state in turn, printing at 50%. The block, if any, runs before each poll, with the
    # number of polls before it.
    def octoprint_states(*states, &before_poll)
      allow(Octoprint::Job).to receive(:get) do
        before_poll&.call(polls.size)
        state = states.shift
        polls << [state, copy.reload.status]
        Octoprint::Job.deserialize({ state:, job: { file: { name: 'test.gcode' } }, progress: { completion: 49.2 } })
      end
    end

    def run_copy
      spool.instance_variable_set(:@active, true)
      spool.send(:run, copy)
    end

    it 'starts it with PrintStart, tracks its progress with PrintProgress and ends it completed with PrintEnd' do
      octoprint_states('Printing', 'Paused', 'Printing', 'Operational')

      run_copy

      expect(polls).to eq [%w[Printing active], %w[Paused active], %w[Printing active], %w[Operational active]]
      expect(UploadFilesToPrintersJob).to have_received(:perform_now).with([copy.executable_id], [printer.id],
                                                                           print: true)
      expect(PrintQueue::PrintProgress).to have_received(:new).with(printer_job: copy, progress: 50).twice
      expect(PrintQueue::PrintEnd).to have_received(:new).with(printer_job: copy, result: 'completed')
      expect(copy.reload).to have_attributes(status: 'completed', progress: 50, started_at: be_present,
                                             finished_at: be_present, bed_cleared_at: nil)
    end

    it 'is idle when PrintEnd asks for the dispatch pass, so that the next start_print is not ignored' do
      octoprint_states('Printing', 'Operational')

      run_copy

      expect(working_at_dispatch).to eq [false]
      expect(spool.instance_variable_get(:@active)).to be false
    end

    it 'ends it as an error when its file cannot be sent' do
      allow(UploadFilesToPrintersJob).to receive(:perform_now).and_raise(Printer::Backend::Unreachable, 'timeout')
      allow(Octoprint::Job).to receive(:get)

      run_copy

      expect(copy.reload).to have_attributes(status: 'error', started_at: be_present, finished_at: be_present)
      expect(Octoprint::Job).not_to have_received(:get)
      expect(working_at_dispatch).to eq [false]
    end

    it 'ends it cancelled when its cancellation was asked while it printed' do
      octoprint_states('Printing', 'Cancelling', 'Operational') do |polled|
        # What PrintQueue::CopyCancellation stamps, once the printer accepted to cancel
        Printer::Job.where(id: copy.id).update_all(cancel_requested_at: Time.current) if polled == 1 # rubocop:disable Rails/SkipsModelValidations
      end

      run_copy

      expect(copy.reload.status).to eq 'cancelled'
    end

    it 'does not start a copy cancelled since the spool picked it up' do
      Printer::Job.where(id: copy.id).update_all(status: 'cancelled') # rubocop:disable Rails/SkipsModelValidations

      run_copy

      expect(copy.reload.status).to eq 'cancelled'
      expect(UploadFilesToPrintersJob).not_to have_received(:perform_now)
      expect(PrintQueue::PrintEnd).not_to have_received(:new)
      expect(operation).to have_received(:log).with(/Not starting the print: Copy 1 of test.gcode has already ended/)
      expect(spool).not_to be_working
    end

    it 'logs a PrintEnd that fails, and retries it while the queue is busy' do
      octoprint_states('Printing', 'Operational')
      attempts = 0
      allow(PrintQueue::PrintEnd).to receive(:new).and_wrap_original do |original, **attributes|
        original.call(**attributes).tap do |print_end|
          allow(print_end).to receive(:save!).and_wrap_original do |save|
            (attempts += 1) < 3 ? raise(ActiveRecord::Deadlocked, 'Deadlock found') : save.call
          end
        end
      end

      run_copy

      expect(attempts).to eq 3
      expect(copy.reload.status).to eq 'completed'
    end

    it 'runs it like any job while the global queue is off: no queue event is recorded' do
      allow(PrintQueue).to receive(:enabled?).and_return(false)
      octoprint_states('Printing', 'Operational')

      run_copy

      expect(copy.reload).to have_attributes(status: 'completed', progress: 50, started_at: nil, finished_at: nil)
      expect(PrintQueue::PrintStart).not_to have_received(:new)
      expect(PrintQueue::PrintProgress).not_to have_received(:new)
      expect(PrintQueue::PrintEnd).not_to have_received(:new)
      expect(dispatch_request).not_to have_received(:save)
    end

    it "runs a job of the printer's own queue like it always did" do
      own_job = create(:printer_job, printer:)
      allow(spool).to receive(:build_operation).and_return(Spooler::Print.new(printer, own_job).tap do |own|
        allow(own).to receive(:sleep)
        allow(own).to receive(:log)
      end)
      octoprint_states('Printing', 'Operational')

      spool.send(:run, own_job)

      expect(own_job.reload).to have_attributes(status: 'completed', started_at: nil)
      expect(PrintQueue::PrintStart).not_to have_received(:new)
      expect(PrintQueue::PrintEnd).not_to have_received(:new)
    end
  end

  describe 'adopting the copy under way after a restart' do
    let(:printer) { create(:printer, name: 'Ender 3') }
    let(:started_at) { 1.hour.ago.change(usec: 0) }
    let(:copy) { create(:printer_job, :copy, printer:, status: 'active', started_at:) }
    let(:polls) { [] }

    before do
      allow(PrintQueue).to receive(:enabled?).and_return(true)
      allow(TentaclesSchema).to receive(:subscriptions)
        .and_return(instance_double(GraphQL::Subscriptions, trigger: nil))
      allow(PrintQueue::DispatchRequest).to receive(:new).and_return(instance_spy(PrintQueue::DispatchRequest))
      allow(UploadFilesToPrintersJob).to receive(:perform_now)
      allow(Spooler::Print).to receive(:new).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).tap do |print|
          allow(print).to receive(:sleep)
          allow(print).to receive(:log)
        end
      end
    end

    # The printer reports each state in turn. At each poll, whether the spool was working and the copy's status are
    # recorded.
    def octoprint_states(*states)
      allow(Octoprint::Job).to receive(:get) do
        state = states.shift
        polls << [state, spool.working?, copy.reload.status]
        Octoprint::Job.deserialize({ state:, job: { file: { name: 'test.gcode' } }, progress: {} })
      end
    end

    # Starts the spool: its thread adopts the copy, without a start_print (the spool isn't resumed)
    def adopt
      spool
      Timeout.timeout(5) { Thread.pass until copy.reload.status != 'active' && !spool.working? }
    end

    it 'monitors it without uploading its file again, the spool working and the copy active meanwhile, then ends it' do
      copy
      octoprint_states('Printing', 'Paused', 'Printing', 'Operational')

      adopt

      expect(polls).to eq [['Printing', true, 'active'], ['Paused', true, 'active'], ['Printing', true, 'active'],
                           ['Operational', true, 'active']]
      expect(UploadFilesToPrintersJob).not_to have_received(:perform_now)
      expect(copy.reload).to have_attributes(status: 'completed', started_at:, finished_at: be_present)
      expect(spool.instance_variable_get(:@active)).to be false
    end

    it 'ends it at the first poll when the print ended while the spooler was down' do
      copy
      octoprint_states('Operational', 'Printing')

      adopt

      expect(polls.map(&:first)).to eq ['Operational']
      expect(copy.reload.status).to eq 'completed'
    end

    it 'ends it cancelled when its cancellation was asked before the restart' do
      copy.update!(cancel_requested_at: 2.minutes.ago)
      octoprint_states('Cancelling', 'Operational')

      adopt

      expect(copy.reload.status).to eq 'cancelled'
    end

    it "leaves an active job of the printer's own queue alone" do
      own_job = create(:printer_job, printer:, status: 'active')
      allow(Octoprint::Job).to receive(:get)

      start_spool

      expect(Octoprint::Job).not_to have_received(:get)
      expect(own_job.reload.status).to eq 'active'
    end

    it 'leaves the active copy alone while the global queue is off, like today' do
      allow(PrintQueue).to receive(:enabled?).and_return(false)
      copy
      allow(Octoprint::Job).to receive(:get)

      start_spool

      expect(Octoprint::Job).not_to have_received(:get)
      expect(copy.reload.status).to eq 'active'
    end
  end
end
