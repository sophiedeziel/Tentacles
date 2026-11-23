# frozen_string_literal: true

require 'rails_helper'
require 'spooler'

RSpec.describe Spooler do
  let(:spooler) { Spooler.new }

  describe '#run' do
    it 'starts the sweep before listening to the commands, which blocks for good' do
      allow(spooler).to receive(:start_sweep)
      allow(spooler).to receive(:subcribe_to_commands)

      spooler.run

      expect(spooler).to have_received(:start_sweep).ordered
      expect(spooler).to have_received(:subcribe_to_commands).ordered
    end
  end

  describe '#start_sweep' do
    it 'sweeps now, then every PrintQueue::SWEEP_INTERVAL, in a thread of its own' do
      swept = Queue.new
      allow(spooler).to receive(:sweep) { swept << Thread.current }
      stub_const('PrintQueue::SWEEP_INTERVAL', 0.01)

      thread = spooler.start_sweep
      2.times { expect(swept.pop(timeout: 5)).to eq thread }
    ensure
      thread&.kill&.join
    end
  end

  describe '#sweep' do
    let(:printer) { create(:printer) }
    let(:other) { create(:printer) }
    let(:workers) { spooler.instance_variable_get(:@workers) }
    let(:sweep) { instance_double(PrintQueue::Sweep, save!: true, printer_ids: [printer.id, other.id]) }

    before do
      spooler # Before the printers: their spools are the doubles below
      allow(PrintQueue).to receive(:enabled?).and_return(true)
      allow(PrintQueue::Sweep).to receive(:new).and_return(sweep)
      allow(spooler).to receive(:log)
      [printer, other].each do |swept|
        workers[swept.id] = instance_double(Spooler::Spool, working?: false, resume: true)
      end
    end

    it 'runs a sweep and resumes the idle spools of the printers with an enqueued copy' do
      allow(workers[other.id]).to receive(:working?).and_return(true)

      spooler.sweep

      expect(sweep).to have_received(:save!)
      expect(workers[printer.id]).to have_received(:resume)
      expect(workers[other.id]).not_to have_received(:resume)
    end

    it 'skips a printer without a spool' do
      workers.delete(other.id)

      spooler.sweep

      expect(workers[printer.id]).to have_received(:resume)
    end

    it 'logs its errors' do
      allow(sweep).to receive(:save!).and_raise(ActiveRecord::StatementInvalid, 'Lost connection')

      spooler.sweep

      expect(spooler).to have_received(:log).with(/Sweep failed: ActiveRecord::StatementInvalid: Lost connection/)
      expect(workers[printer.id]).not_to have_received(:resume)
    end

    it 'does nothing while the global queue is off' do
      allow(PrintQueue).to receive(:enabled?).and_return(false)

      spooler.sweep

      expect(PrintQueue::Sweep).not_to have_received(:new)
      expect(workers[printer.id]).not_to have_received(:resume)
    end
  end

  describe '#log' do
    it 'formats the message' do
      expect { spooler.log 'test' }.to output("         [ Spooler ] : test\n").to_stdout
    end
  end

  describe 'commands' do
    let(:printer) { create(:printer, name: 'Ender 3') }
    # The messages published on the printers channel, in order
    let(:messages) { [] }
    # Stands in for Redis#subscribe: hands each message to the on.message block, then returns as if unsubscribed
    let(:redis) { instance_double(Redis) }
    let(:workers) { spooler.instance_variable_get(:@workers) }

    before do
      allow(redis).to receive(:subscribe).with('printers') do |&block|
        subscription = Redis::Subscription.new(&block)
        messages.each { |message| subscription.callbacks['message'].call('printers', message.to_json) }
      end
      stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
      allow(spooler).to receive(:log)
    end

    after { workers.each_value { |spool| spool.instance_variable_get(:@thread).kill.join } }

    it 'keeps listening after a message for a printer removed since' do
      spooler
      messages.push({ command: 'start_print', printer_id: printer.id + 1 },
                    { command: 'remove_printer', printer_id: printer.id + 1 },
                    { command: 'add_printer', printer_id: printer.id })

      spooler.subcribe_to_commands

      expect(spooler).to have_received(:log).with(/Couldn't find Printer/)
      expect(workers.keys).to eq [printer.id]
    end

    it 'logs an unknown command and keeps listening' do
      spooler
      messages.push({ command: 'reboot', printer_id: printer.id },
                    { command: 'add_printer', printer_id: printer.id })

      spooler.subcribe_to_commands

      expect(spooler).to have_received(:log).with(/key not found: "reboot"/)
      expect(workers.keys).to eq [printer.id]
    end

    describe 'dispatch, for the whole queue' do
      let(:dispatch) { instance_double(PrintQueue::Dispatch, save!: true) }

      before do
        spooler
        allow(PrintQueue::Dispatch).to receive(:new).and_return(dispatch)
        allow(Printer).to receive(:find).and_call_original
      end

      it 'runs a dispatch pass, without looking a printer up, and keeps listening' do
        messages.push({ command: 'dispatch' }, { command: 'add_printer', printer_id: printer.id })

        spooler.subcribe_to_commands

        expect(dispatch).to have_received(:save!).once
        expect(spooler).not_to have_received(:log).with(/Couldn't find Printer/)
        expect(Printer).to have_received(:find).once.with(printer.id)
        expect(workers.keys).to eq [printer.id]
      end

      it 'logs a pass that failed and keeps listening' do
        allow(dispatch).to receive(:save!).and_raise(ActiveRecord::Deadlocked, 'Deadlock found')
        messages.push({ command: 'dispatch' }, { command: 'add_printer', printer_id: printer.id })

        spooler.subcribe_to_commands

        expect(spooler).to have_received(:log).with(/Dispatch failed: ActiveRecord::Deadlocked: Deadlock found/)
        expect(workers.keys).to eq [printer.id]
      end
    end

    context 'when a printer is removed mid-print' do
      let(:api) do
        instance_spy(Printer::Backend,
                     print_progress: { state_family: Printer::StateFamily::Printing, progress: 10.0 })
      end
      let!(:job) { create(:printer_job, printer:) }
      let(:spool) { Spooler::Spool.new(printer) }

      before do
        allow(printer).to receive_messages(api:, update_subscribers: nil)
        allow(UploadFilesToPrintersJob).to receive(:perform_now)
        allow_any_instance_of(Spooler::Print).to receive(:log)
        workers[printer.id] = spool
        spool.resume
        Timeout.timeout(5) { Thread.pass until job.reload.status == 'active' && spool.working? }
        messages.push({ command: 'remove_printer', printer_id: printer.id })
      end

      it 'stops its spool without sending anything to the printer' do
        operation = spool.instance_variable_get(:@current_operation)
        allow(operation).to receive(:interrupt)
        thread = spool.instance_variable_get(:@thread)

        spooler.subcribe_to_commands

        expect(thread.join(2)).to eq thread # the thread is over
        expect(workers).not_to have_key(printer.id)
        expect(operation).not_to have_received(:interrupt)
        %i[pause resume cancel connect reconnect upload].each do |command|
          expect(api).not_to have_received(command)
        end
      end
    end
  end
end
