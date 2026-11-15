# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Job, type: :model do
  it 'has a valid factory' do
    expect(build(:printer_job)).to be_valid
  end

  describe 'printQueueChanged' do
    let(:subscriptions) { TentaclesSchema.subscriptions }
    let(:printer) { create(:printer) }
    let(:job) { create(:printer_job, printer:) }
    # The printQueueChanged triggers, as [printer id, ...]
    let(:pushes) { [] }

    before do
      allow(subscriptions).to receive(:trigger) do |name, arguments, object|
        pushes << object.id if name == :print_queue_changed && arguments == {}
      end
      job
      pushes.clear
    end

    it 'is pushed with the printer when a job is enqueued' do
      other = create(:printer_job)

      expect(pushes).to eq [other.printer_id]
    end

    it 'is pushed when a job is removed' do
      job.destroy!

      expect(pushes).to eq [printer.id]
    end

    it 'is pushed when a job changes status' do
      job.update!(status: 'active')
      job.update!(progress: 100, status: 'completed')

      expect(pushes).to eq [printer.id, printer.id]
    end

    it 'is not pushed by progress updates, which the spooler writes twice a second' do
      job.update!(status: 'active')
      10.times { |tick| job.update!(progress: tick * 10.0) }
      described_class.find(job.id).update!(progress: 100)

      expect(pushes).to eq [printer.id] # the status change only
    end

    it 'is not pushed by a save that changes nothing' do
      job.save!
      job.update!(updated_at: Time.current)

      expect(pushes).to be_empty
    end

    it 'is pushed once, on commit, for a job enqueued then updated in one transaction' do
      described_class.transaction do
        other = create(:printer_job, printer:)
        other.update!(progress: 5)
        expect(pushes).to be_empty
      end

      expect(pushes).to eq [printer.id]
    end

    it 'is not pushed when the transaction rolls back' do
      described_class.transaction do
        job.update!(status: 'active')
        raise ActiveRecord::Rollback
      end
      job.reload.update!(progress: 10)

      expect(pushes).to be_empty
    end

    it 'saves the job even when the push fails' do
      allow(subscriptions).to receive(:trigger).and_raise(Redis::CannotConnectError)
      allow(Rails.logger).to receive(:error)

      expect { job.update!(status: 'active') }.not_to raise_error
      expect(job.reload.status).to eq 'active'
      expect(Rails.logger).to have_received(:error).with(/Could not push printQueueChanged/)
    end
  end
end
