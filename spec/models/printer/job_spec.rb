# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Job, type: :model do
  it 'has a valid factory' do
    expect(build(:printer_job)).to be_valid
  end

  describe 'status' do
    it 'is one of enqueued, active, completed, error and cancelled' do
      statuses = %w[enqueued active completed error cancelled]

      expect(statuses.map { |status| build(:printer_job, status:) }).to all(be_valid)
      expect(build(:printer_job, status: 'failed')).not_to be_valid
    end

    it 'counts a cancelled job as finished' do
      job = create(:printer_job, status: 'cancelled')

      expect(described_class.finished).to eq [job]
    end
  end

  describe 'print_job' do
    it 'is nil for a job enqueued on the printer' do
      expect(build(:printer_job).print_job).to be_nil
    end

    it 'is the global queue entry of a copy, numbered from 1' do
      entry = create(:print_job)
      copies = create_list(:printer_job, 2, :copy, print_job: entry)

      expect(copies.map(&:copy_number)).to eq [1, 2]
      expect(entry.printer_jobs).to match_array copies
    end
  end

  describe 'queue columns' do
    it 'stores the filament snapshot, the times and the bed state' do
      job = create(:printer_job, :copy, filament: [{ 'slot' => 1, 'material' => 'PLA', 'colour' => 'Black' }],
                                        started_at: 2.hours.ago, finished_at: 1.hour.ago,
                                        bed_cleared_at: Time.current, bed_cleared_by: 'automatic')

      expect(job.reload).to have_attributes(filament: [{ 'slot' => 1, 'material' => 'PLA', 'colour' => 'Black' }],
                                            bed_cleared_by_automatic?: true)
    end

    it 'leaves them empty for an old-style job' do
      expect(create(:printer_job).reload)
        .to have_attributes(print_job_id: nil, copy_number: nil, started_at: nil, finished_at: nil, filament: nil,
                            bed_cleared_at: nil, bed_cleared_by: nil)
    end

    it 'knows who cleared the bed: a person or the printer itself' do
      expect(build(:printer_job, bed_cleared_by: 'person')).to be_bed_cleared_by_person
      expect(build(:printer_job, bed_cleared_by: 'robot')).not_to be_valid
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
