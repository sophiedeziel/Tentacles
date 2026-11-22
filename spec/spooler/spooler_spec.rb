# frozen_string_literal: true

require 'rails_helper'
require 'spooler'

RSpec.describe Spooler do
  let(:spooler) { Spooler.new }

  describe '#run' do
    subject { spooler.run }

    it 'runs the spooler in a loop' do
      allow(spooler).to receive(:subcribe_to_commands)
      expect(spooler).to receive(:loop).and_yield
      subject
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
