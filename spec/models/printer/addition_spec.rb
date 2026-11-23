# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Addition do
  # MockRedis has no pub/sub: what the spooler is sent
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }
  let(:attributes) do
    { name: 'Ender 3', backend: 'octoprint', uri: 'http://192.168.1.57/', secret: 'A8DDB1359AAB415AB38C345129815DF4' }
  end
  let(:addition) { described_class.new(**attributes) }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(redis).to receive(:publish).and_call_original
    # The specs come from the printer's server: never reached here
    allow(addition.printer).to receive(:fill_specs_from_server)
  end

  context 'with a valid printer' do
    it 'saves the printer, readable as #printer' do
      expect { expect(addition.save).to be(true) }.to change(Printer, :count).by(1)

      expect(addition.printer).to be_persisted
      expect(addition.printer).to eq(Printer.last)
      expect(Printer.last).to have_attributes(name: 'Ender 3', backend: 'octoprint', uri: 'http://192.168.1.57/',
                                              username: nil, secret: 'A8DDB1359AAB415AB38C345129815DF4')
      expect(addition.errors).to be_empty
    end

    it 'tells the spooler, so that the printer gets a spool without a restart' do
      addition.save!

      expect(redis).to have_received(:publish)
        .with('printers', { command: 'add_printer', printer_id: addition.printer.id }.to_json).once
    end

    it 'fills the blank specs from the printer server, once saved' do
      allow(addition.printer).to receive(:fill_specs_from_server) { expect(addition.printer).to be_persisted }

      addition.save!

      expect(addition.printer).to have_received(:fill_specs_from_server).once
    end

    it 'keeps the PrusaLink username' do
      addition = described_class.new(name: 'MK4', backend: 'prusalink', uri: 'http://prusa-mk4.local',
                                     username: 'maker', secret: 'printer-password')
      allow(addition.printer).to receive(:fill_specs_from_server)

      addition.save!

      expect(Printer.last).to have_attributes(backend: 'prusalink', username: 'maker', secret: 'printer-password')
    end
  end

  context 'without a backend' do
    let(:attributes) { super().except(:backend) }

    it "gets the printer's default backend, OctoPrint" do
      addition.save!

      expect(Printer.last.backend).to eq('octoprint')
    end
  end

  context 'when the spooler cannot be told' do
    before do
      allow(redis).to receive(:publish).and_raise(Redis::CannotConnectError, 'Connection refused')
      allow(Rails.logger).to receive(:error)
    end

    it 'still adds the printer and fills its specs, and logs the failure' do
      expect(addition.save).to be(true)

      expect(addition.printer).to be_persisted
      expect(addition.printer).to have_received(:fill_specs_from_server)
      expect(Rails.logger).to have_received(:error)
        .with("[Printer::Addition] Could not publish add_printer for printer #{addition.printer.id}: " \
              'Connection refused')
    end
  end

  context 'with an invalid printer' do
    let(:attributes) { { name: 'Ender 3', uri: '', secret: nil } }

    it "returns false with the printer's errors, named like the printer's attributes" do
      expect(addition.save).to be(false)
      expect(addition.errors.full_messages)
        .to contain_exactly("URL can't be blank", "API key or password can't be blank")
      expect(addition.errors.attribute_names).to contain_exactly(:uri, :secret)
    end

    it 'saves nothing, tells nobody and reads no specs' do
      expect { addition.save }.not_to change(Printer, :count)

      expect(addition.printer).not_to be_persisted
      expect(redis).not_to have_received(:publish)
      expect(addition.printer).not_to have_received(:fill_specs_from_server)
    end

    it 'raises ActiveModel::ValidationError from #save!' do
      expect { addition.save! }.to raise_error(ActiveModel::ValidationError, /URL can't be blank/)
    end
  end

  context 'with an unknown backend' do
    let(:attributes) { super().merge(backend: 'klipper') }

    it 'is invalid' do
      expect(addition.save).to be(false)
      expect(addition.errors.attribute_names).to eq([:backend])
      expect(Printer.count).to eq(0)
    end
  end
end
