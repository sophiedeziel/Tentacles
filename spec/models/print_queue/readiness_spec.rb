# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Readiness do
  let(:printer) { build(:printer) }
  let(:entry) { build(:print_job) }

  def status(family, state_text = family.serialize.capitalize)
    Printer::Status.new(printer_id: 1, state_family: family, state_text:)
  end

  # Ready to take `entry`, unless an input says otherwise
  def readiness(**inputs)
    described_class.new(printer:, status: status(Printer::StateFamily::Operational), has_unfinished_job: false,
                        bed_needs_clearing: false, dispatch_paused: false, next_job: entry, **inputs)
  end

  def reason(readiness) = readiness.reason&.to_h

  it 'is ready, without an idle reason, when it takes an entry' do
    expect(readiness).to be_ready
    expect(readiness).to be_free
    expect(readiness.idle_reason).to be_nil
    expect(readiness.reason).to be_nil
  end

  describe 'idle reasons' do
    it 'is :dispatch_paused while dispatch is paused' do
      expect(reason(readiness(dispatch_paused: true))).to eq(code: :dispatch_paused, message: 'Dispatch is paused')
    end

    it 'is :not_taking_jobs when the printer does not take jobs' do
      printer.takes_jobs = false

      expect(reason(readiness)).to eq(code: :not_taking_jobs, message: 'Not taking jobs')
    end

    it 'is :offline without a snapshot, or when Offline, Connecting or in Error' do
      expect(reason(readiness(status: nil))).to eq(code: :offline, message: 'Offline')
      expect(readiness(status: status(Printer::StateFamily::Offline)).idle_reason).to eq :offline
      expect(readiness(status: status(Printer::StateFamily::Connecting)).idle_reason).to eq :offline
      expect(readiness(status: status(Printer::StateFamily::Error)).idle_reason).to eq :offline
    end

    it 'is :busy when printing, paused or cancelling' do
      expect(reason(readiness(status: status(Printer::StateFamily::Printing, 'Printing from SD'))))
        .to eq(code: :busy, message: 'Busy: Printing from SD')
      expect(readiness(status: status(Printer::StateFamily::Paused)).idle_reason).to eq :busy
      expect(readiness(status: status(Printer::StateFamily::Cancelling)).idle_reason).to eq :busy
    end

    it 'is :busy with an unfinished job (old-style per-printer jobs included)' do
      expect(reason(readiness(has_unfinished_job: true))).to eq(code: :busy, message: 'Busy: has a job to finish')
    end

    it 'is :bed_not_cleared when its last print is still on the bed' do
      expect(reason(readiness(bed_needs_clearing: true))).to eq(code: :bed_not_cleared, message: 'Bed not cleared')
    end

    it 'is :nothing_eligible when no entry fits it' do
      idle = readiness(next_job: nil)

      expect(reason(idle)).to eq(code: :nothing_eligible, message: 'Nothing to print')
      expect(idle).to be_free
      expect(idle).not_to be_ready
    end

    it 'are checked in order: the first that applies is the reason' do
      printer.takes_jobs = false
      inputs = { dispatch_paused: true, status: nil, has_unfinished_job: true, bed_needs_clearing: true,
                 next_job: nil }

      reasons = described_class::IDLE_REASONS.map do |code|
        idle_reason = readiness(**inputs).idle_reason
        case code
        when :dispatch_paused then inputs[:dispatch_paused] = false
        when :not_taking_jobs then printer.takes_jobs = true
        when :offline then inputs[:status] = status(Printer::StateFamily::Operational)
        when :busy then inputs[:has_unfinished_job] = false
        when :bed_not_cleared then inputs[:bed_needs_clearing] = false
        end
        idle_reason
      end

      expect(reasons).to eq described_class::IDLE_REASONS
    end

    it 'leave the printer not free, except :nothing_eligible' do
      expect(readiness(dispatch_paused: true)).not_to be_free
      expect(readiness(status: nil)).not_to be_free
      expect(readiness(bed_needs_clearing: true)).not_to be_free
    end
  end

  describe '.for' do
    let(:printer) { create(:printer) }
    let(:operational) do
      Printer::Status.new(printer_id: printer.id, state_family: Printer::StateFamily::Operational,
                          state_text: 'Operational')
    end

    before { allow(Printer::Status).to receive(:find_by).with(printer_id: printer.id).and_return(operational) }

    def queued_entry
      create(:print_job).tap { |job| create(:gcode_summary, :failed, item: job.item) }
    end

    it 'is ready with the next job of the printer' do
      first = queued_entry

      readiness = described_class.for(printer)

      expect(readiness).to be_ready
      expect(readiness.next_job).to eq first
    end

    it 'is :nothing_eligible with an empty queue' do
      expect(described_class.for(printer).idle_reason).to eq :nothing_eligible
    end

    it 'is :busy with an old-style job enqueued on the printer' do
      queued_entry
      create(:printer_job, printer:, status: 'enqueued')

      expect(described_class.for(printer).idle_reason).to eq :busy
    end

    it 'is :bed_not_cleared when the printer says so' do
      allow(printer).to receive(:bed_needs_clearing?).and_return(true)

      expect(described_class.for(printer).idle_reason).to eq :bed_not_cleared
    end

    it 'is :dispatch_paused from the setting, without looking for a job' do
      create(:print_queue_setting, dispatch_paused: true)
      allow(PrintQueue::NextJob).to receive(:for)

      expect(described_class.for(printer).idle_reason).to eq :dispatch_paused
      expect(PrintQueue::NextJob).not_to have_received(:for)
    end

    it 'is :offline without a snapshot' do
      allow(Printer::Status).to receive(:find_by).with(printer_id: printer.id).and_return(nil)

      expect(described_class.for(printer).idle_reason).to eq :offline
    end
  end

  it 'is read-only' do
    expect { readiness.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
