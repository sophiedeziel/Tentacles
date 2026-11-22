# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Job, type: :model do
  it 'has a valid factory' do
    expect(build(:printer_job)).to be_valid
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
