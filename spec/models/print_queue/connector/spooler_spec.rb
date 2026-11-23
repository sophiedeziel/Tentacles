# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Connector::Spooler do
  let(:connector) { described_class.new }
  let(:printer_job) { create(:printer_job, :copy, print_job: create(:print_job)) }
  # MockRedis doesn't implement PUBLISH
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(redis).to receive(:publish)
  end

  it 'is the default connector' do
    expect(PrintQueue.connector).to be_a described_class
  end

  describe '#start' do
    it "asks the spooler to start the copy's printer" do
      connector.start(printer_job)

      expect(redis).to have_received(:publish)
        .once.with('printers', { command: 'start_print', printer_id: printer_job.printer_id }.to_json)
    end

    [Redis::CannotConnectError, ConnectionPool::TimeoutError].each do |error|
      it "logs #{error.name} without raising: the sweep starts the copy" do
        allow(redis).to receive(:publish).and_raise(error, 'Connection refused')
        allow(Rails.logger).to receive(:error)

        expect { connector.start(printer_job) }.not_to raise_error
        expect(Rails.logger).to have_received(:error)
          .with(/Could not publish start_print for printer #{printer_job.printer_id}: #{error.name}/)
      end
    end
  end

  {
    pause: Printer::Pause, resume: Printer::Resumption, cancel: Printer::Cancellation
  }.each do |method, command_class|
    describe "##{method}" do
      it "saves a #{command_class.name} for the copy's printer, guarded by the copy's file name, and returns it" do
        command = instance_double(command_class, save: false)
        allow(command_class).to receive(:new)
          .with(printer: printer_job.printer, expected_file_name: printer_job.name).and_return(command)

        expect(connector.public_send(method, printer_job)).to eq command
        expect(command).to have_received(:save)
      end
    end
  end
end
