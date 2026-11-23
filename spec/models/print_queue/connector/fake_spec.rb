# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Connector::Fake do
  let(:fake) { described_class.new }
  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:copy) { create(:printer_job, :copy, printer:) }
  let(:dispatch_request) { instance_spy(PrintQueue::DispatchRequest, save: true) }

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    allow(PrintQueue).to receive(:push_changed)
    allow(PrintQueue::DispatchRequest).to receive(:new).and_return(dispatch_request)
    allow(TentaclesSchema).to receive(:subscriptions).and_return(instance_double(GraphQL::Subscriptions, trigger: nil))
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { MockRedis.new })
  end

  def status = Printer::Status.find_by(printer_id: printer.id)

  describe 'the commands the queue sends' do
    it 'records them in order, without calling the printer' do
      other = create(:printer_job, :copy, printer:)

      fake.start(copy)
      fake.pause(copy)
      fake.resume(copy)
      fake.start(other)
      fake.cancel(copy)

      expect(fake.commands).to eq [[:start, copy], [:pause, copy], [:resume, copy], [:start, other], [:cancel, copy]]
      expect(fake.received(:start)).to eq [copy, other]
      expect(fake.received(:cancel)).to eq [copy]
    end

    {
      pause: Printer::Pause, resume: Printer::Resumption, cancel: Printer::Cancellation
    }.each do |method, command_class|
      it "accepts #{method}: a #{command_class.name} without errors, not saved" do
        command = fake.public_send(method, copy)

        expect(command).to be_a command_class
        expect(command).to have_attributes(printer:, errors: be_empty)
      end
    end

    it 'refuses with its refusal' do
      fake.refusal = 'Prusa MK4 is no longer printing'

      expect(fake.pause(copy).errors[:base]).to eq ['Prusa MK4 is no longer printing']
    end
  end

  describe 'what the printers do, fired by hand' do
    it 'ready!: writes an Operational snapshot, then asks for a dispatch pass (PrinterReady)' do
      fake.ready!(printer)

      expect(status).to have_attributes(state_family: Printer::StateFamily::Operational, state_text: 'Operational',
                                        last_seen_at: be_present)
      expect(dispatch_request).to have_received(:save)
    end

    it 'offline!: writes an Offline snapshot that keeps when it was last seen, then pushes it (PrinterOffline)' do
      fake.ready!(printer)
      seen = status.last_seen_at

      fake.offline!(printer)

      expect(status).to have_attributes(state_family: Printer::StateFamily::Offline, state_text: 'Offline',
                                        last_seen_at: seen)
      expect(PrintQueue).to have_received(:push_changed).with([printer])
    end

    it 'started!: starts the copy (PrintStart), and the printer prints it' do
      fake.started!(copy)

      expect(copy.reload).to have_attributes(status: 'active', started_at: be_present)
      expect(status).to have_attributes(state_family: Printer::StateFamily::Printing, file_name: copy.name,
                                        progress: 0)
    end

    it 'progressed!: writes its progress (PrintProgress) and the printer reports it' do
      fake.started!(copy)
      fake.progressed!(copy, 40)

      expect(copy.reload.progress).to eq 40
      expect(status.progress).to eq 40
    end

    it 'paused!: the printer is paused and the queue pushed (PrintPause), the copy still active' do
      fake.started!(copy)
      fake.paused!(copy)

      expect(status.state_family).to eq Printer::StateFamily::Paused
      expect(copy.reload.status).to eq 'active'
      expect(PrintQueue).to have_received(:push_changed).with([printer]).twice
    end

    it 'ended!: the printer is idle, the copy ends completed (PrintEnd) and a dispatch pass is asked for' do
      fake.started!(copy)
      fake.ended!(copy)

      expect(status.state_family).to eq Printer::StateFamily::Operational
      expect(copy.reload).to have_attributes(status: 'completed', finished_at: be_present)
      expect(dispatch_request).to have_received(:save)
    end

    it 'ended!: ends it with the result given' do
      fake.started!(copy)
      fake.ended!(copy, 'error')

      expect(copy.reload.status).to eq 'error'
    end

    it 'raises when the queue refuses the event' do
      expect { fake.ended!(copy) }.to raise_error(ActiveModel::ValidationError, /Copy 1 of test.gcode hasn't started/)
    end
  end
end
