# frozen_string_literal: true

require 'rails_helper'
require 'support/unreadable_secret'

RSpec.describe Printer::Monitor::Supervisor do
  include UnreadableSecret

  let(:redis) { MockRedis.new }
  let(:started) { [] }
  let(:worker_factory) do
    lambda do |printer|
      instance_double(Printer::Monitor::Worker, printer:, stop: nil, join: nil).tap do |worker|
        allow(worker).to receive(:start).and_return(worker)
        started << worker
      end
    end
  end
  let(:supervisor) { described_class.new(worker_factory:) }

  let!(:printer) { create(:printer) }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
  end

  def write_snapshot(printer_id)
    Printer::Status.unknown(printer_id:).save!
  end

  describe '#refresh' do
    it 'starts a worker per printer' do
      other = create(:printer, name: 'Other')
      supervisor.refresh

      expect(supervisor.workers.keys).to contain_exactly(printer.id, other.id)
      expect(started).to all(have_received(:start))
    end

    it 'keeps starting the other workers when one printer fails' do
      other = create(:printer, name: 'Other')
      factory = worker_factory
      failing = lambda do |p|
        raise ArgumentError, 'Unknown printer backend' if p.id == printer.id

        factory.call(p)
      end
      allow(Rails.logger).to receive(:error).and_call_original

      supervisor = described_class.new(worker_factory: failing)
      supervisor.refresh

      expect(supervisor.workers.keys).to eq [other.id]
      expect(Rails.logger).to have_received(:error).with(/Failed to monitor Printer \(##{printer.id}\): ArgumentError/)
    end

    it 'starts the worker of a printer whose secret cannot be decrypted' do
      unreadable = make_secret_unreadable(create(:printer, name: 'Unreadable'))
      supervisor.refresh

      expect(supervisor.workers.keys).to contain_exactly(printer.id, unreadable.id)
    end

    it 'does not restart workers when nothing changed' do
      supervisor.refresh
      supervisor.refresh

      expect(started.size).to eq 1
      expect(started.first).not_to have_received(:stop)
    end

    it 'adds a worker for a new printer' do
      supervisor.refresh
      added = create(:printer, name: 'New')
      supervisor.refresh

      expect(supervisor.workers.keys).to contain_exactly(printer.id, added.id)
      expect(started.size).to eq 2
    end

    context 'when a printer is removed' do
      let!(:removed) { create(:printer, name: 'Removed') }

      before do
        supervisor.refresh
        write_snapshot(removed.id)
        write_snapshot(printer.id)
        removed.destroy!
        supervisor.refresh
      end

      let(:removed_worker) { started.find { |worker| worker.printer.id == removed.id } }

      it 'stops its worker' do
        expect(removed_worker).to have_received(:stop)
        expect(removed_worker).to have_received(:join)
        expect(supervisor.workers.keys).to eq [printer.id]
      end

      it 'deletes its snapshot only' do
        expect(Printer::Status.find_by(printer_id: removed.id)).to be_nil
        expect(Printer::Status.find_by(printer_id: printer.id)).to be_present
      end
    end

    %i[uri secret].each do |attribute|
      context "when the printer's #{attribute} changed" do
        before do
          supervisor.refresh
          printer.update!(attribute => 'http://10.0.1.166/')
          supervisor.refresh
        end

        it 'restarts its worker with the new credentials' do
          old_worker, new_worker = started
          expect(old_worker).to have_received(:stop)
          expect(new_worker.printer.public_send(attribute)).to eq 'http://10.0.1.166/'
          expect(supervisor.workers[printer.id]).to eq new_worker
        end
      end
    end

    it 'does not restart the worker when another attribute changed' do
      supervisor.refresh
      printer.update!(name: 'Renamed')
      supervisor.refresh

      expect(started.size).to eq 1
    end

    it 'keeps the workers running when the printers cannot be read' do
      supervisor.refresh
      allow(Printer).to receive(:all).and_raise(ActiveRecord::ConnectionNotEstablished)

      expect { supervisor.refresh }.not_to raise_error
      expect(supervisor.workers.keys).to eq [printer.id]
    end
  end

  describe '#step' do
    context 'when there are no printers' do
      before { printer.destroy! }

      it 'writes the heartbeat' do
        supervisor.step
        expect(Printer::Monitor::Heartbeat.healthy?).to be true
        expect(supervisor.workers).to be_empty
      end
    end

    it 'writes the heartbeat on every step (every 5 seconds)' do
      allow(Printer::Monitor::Heartbeat).to receive(:create!)
      7.times { supervisor.step }
      expect(Printer::Monitor::Heartbeat).to have_received(:create!).exactly(7).times
    end

    it 'refreshes the printers every 30 seconds (every 6 steps)' do
      allow(supervisor).to receive(:refresh)
      13.times { supervisor.step }
      expect(supervisor).to have_received(:refresh).exactly(3).times # Steps 1, 7 and 13
    end

    it 'follows a custom refresh interval' do
      supervisor = described_class.new(worker_factory:, refresh_interval: 10.0, heartbeat_interval: 5.0)
      allow(supervisor).to receive(:refresh)
      4.times { supervisor.step }
      expect(supervisor).to have_received(:refresh).twice
    end

    context 'when the heartbeat cannot be written' do
      before { allow(redis).to receive(:set).and_raise(Redis::CannotConnectError) }

      it 'does not raise and logs only the first failure of the streak' do
        allow(Rails.logger).to receive(:error).and_call_original
        expect { 3.times { supervisor.step } }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Failed to write the heartbeat/).once
      end
    end
  end

  describe '#run' do
    before do
      allow(Signal).to receive(:trap)
      supervisor.stop # Stops after the first step
    end

    it 'refreshes, beats, then stops and joins every worker' do
      supervisor.run

      expect(Printer::Monitor::Heartbeat.healthy?).to be true
      expect(started.size).to eq 1
      expect(started.first).to have_received(:stop)
      expect(started.first).to have_received(:join)
      expect(supervisor.workers).to be_empty
    end

    it 'traps INT and TERM' do
      supervisor.run

      expect(Signal).to have_received(:trap).with('INT')
      expect(Signal).to have_received(:trap).with('TERM')
    end
  end

  it 'uses Printer::Monitor::Worker by default' do
    worker = instance_double(Printer::Monitor::Worker)
    allow(worker).to receive(:start).and_return(worker)
    allow(Printer::Monitor::Worker).to receive(:new).with(printer:).and_return(worker)

    described_class.new.refresh

    expect(worker).to have_received(:start)
  end
end
