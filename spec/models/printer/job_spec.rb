# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Job, type: :model do
  it 'has a valid factory' do
    expect(build(:printer_job)).to be_valid
  end

  describe 'status' do
    it 'counts a cancelled job as finished' do
      job = create(:printer_job, status: 'cancelled')

      expect(described_class.finished).to eq [job]
    end
  end

  describe '#bed_dwell' do
    let(:finished_at) { 2.hours.ago.change(usec: 0) }

    it 'is the seconds the print sat on the bed, from its end to the bed being cleared' do
      job = build(:printer_job, status: 'completed', finished_at:, bed_cleared_at: finished_at + 25.minutes)

      expect(job.bed_dwell).to eq 1500.0
    end

    it 'is nil until the bed is cleared' do
      expect(build(:printer_job, status: 'completed', finished_at:).bed_dwell).to be_nil
    end

    it 'is nil for a job that never finished' do
      expect(build(:printer_job, status: 'active').bed_dwell).to be_nil
    end
  end

  describe '#copy?' do
    it 'is true for a copy of a global queue entry, false for a job of the printer' do
      expect(create(:printer_job, :copy)).to be_copy
      expect(build(:printer_job)).not_to be_copy
    end
  end

  describe '#push_print_queue_changed' do
    let(:subscriptions) { TentaclesSchema.subscriptions }
    let(:printer) { create(:printer) }
    let(:job) { create(:printer_job, printer:) }
    # The printQueueChanged triggers, as [printer id, ...]
    let(:pushes) { [] }

    before do
      allow(subscriptions).to receive(:trigger) do |name, arguments, object|
        pushes << object.id if name == :print_queue_changed && arguments == {}
      end
    end

    it 'pushes the printer of the job' do
      job.push_print_queue_changed

      expect(pushes).to eq [printer.id]
    end

    it 'is left to the writer: saving or destroying a job pushes nothing' do
      job.update!(status: 'active')
      job.update!(progress: 50)
      job.destroy!

      expect(pushes).to be_empty
    end

    it 'logs a push that fails, without raising' do
      allow(subscriptions).to receive(:trigger).and_raise(Redis::CannotConnectError)
      allow(Rails.logger).to receive(:error)

      expect { job.push_print_queue_changed }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/Could not push printQueueChanged/)
    end
  end
end
