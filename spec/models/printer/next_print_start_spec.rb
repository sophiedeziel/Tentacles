# frozen_string_literal: true

require 'rails_helper'
require_relative 'command_shared_examples'

RSpec.describe Printer::NextPrintStart do
  include_context 'with a printer command'

  # MockRedis doesn't implement PUBLISH
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }
  let(:live_job) { { state_family: Printer::StateFamily::Operational, file_name: nil, job_id: nil } }
  let!(:next_job) { create(:printer_job, printer:, status: 'enqueued', created_at: 1.hour.ago) }
  let(:start_print_message) { { command: :start_print, printer_id: printer.id }.to_json }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(redis).to receive(:publish)
  end

  def start(**expectations)
    described_class.new(printer:, **expectations).tap(&:save)
  end

  def expect_refusal(message, **expectations)
    expect(start(**expectations).errors.full_messages).to eq([message])
    expect(redis).not_to have_received(:publish)
  end

  context 'when the printer is OPERATIONAL, with a queue and no active job' do
    it 'asks the spooler to start the next print' do
      expect(start.errors).to be_empty
      expect(redis).to have_received(:publish).with('printers', start_print_message).once
    end

    it 'leaves the status refresh to the spooler' do
      start

      expect(Printer::Status).not_to have_received(:find_or_initialize_by)
    end
  end

  (Printer::StateFamily.values - [Printer::StateFamily::Operational]).each do |family|
    context "when the printer is #{family.serialize}" do
      let(:live_job) { super().merge(state_family: family) }

      it { expect_refusal('Prusa MK4 is not ready to print') }
    end
  end

  it 'refuses when the queue is empty' do
    next_job.update!(status: 'completed')
    create(:printer_job, status: 'enqueued') # another printer's

    expect_refusal('Prusa MK4 has nothing in its queue')
  end

  it 'refuses when the printer already has an active job' do
    create(:printer_job, printer:, status: 'active')

    expect_refusal('Prusa MK4 already has an active job')
  end

  describe 'the job the user confirmed' do
    it 'starts the queue when its next job is the confirmed one' do
      create(:printer_job, printer:, status: 'enqueued')

      expect(start(expected_job_id: next_job.id.to_s).errors).to be_empty
      expect(redis).to have_received(:publish).once
    end

    it 'refuses when another job is now first' do
      other = create(:printer_job, printer:, status: 'enqueued', created_at: 2.hours.ago)
      other.executable.file.blob.update!(filename: 'gear_v2.gcode')

      expect_refusal("Prusa MK4's next job is now gear_v2.gcode", expected_job_id: next_job.id.to_s)
    end

    it 'does not check the job when none is given' do
      create(:printer_job, printer:, status: 'enqueued', created_at: 2.hours.ago)

      expect(start.errors).to be_empty
    end
  end

  context 'when Redis is down' do
    before do
      allow(redis).to receive(:publish).and_raise(Redis::CannotConnectError, 'Connection refused')
      allow(Rails.logger).to receive(:error)
    end

    it 'returns a readable error and logs why' do
      command = start

      expect(command.errors.full_messages).to eq(["Could not ask the spooler to start Prusa MK4's next print"])
      expect(Rails.logger).to have_received(:error).with(/Could not publish start_print for printer #{printer.id}/)
    end

    it 'raises with save!' do
      expect { described_class.new(printer:).save! }.to raise_error(described_class::SpoolerUnreachable)
    end
  end

  it 'words the printer API failures like the other commands' do
    allow(printer.api).to receive(:live_job).and_raise(Printer::Backend::Unreachable, 'timeout')

    expect_refusal("Could not reach Prusa MK4's OctoPrint: timeout")
  end
end
