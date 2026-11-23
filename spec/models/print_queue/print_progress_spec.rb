# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::PrintProgress do
  include_context 'with a queue operation'

  let(:printer) { create(:printer) }
  let(:printer_job) { create(:printer_job, :copy, printer:, status: 'active') }

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer_job:, progress: 43) }
  end

  it "writes the copy's progress, without a push or a dispatch request" do
    expect(described_class.new(printer_job:, progress: 43).save).to be true

    expect(printer_job.reload.progress).to eq 43
    expect(PrintQueue).not_to have_received(:push_changed)
    expect_no_dispatch_requested
  end

  [-1, 100.5].each do |progress|
    it "is invalid with a progress of #{progress}" do
      expect_refused(described_class.new(printer_job:, progress:), 'Progress must be in 0..100')
      expect(printer_job.reload.progress).to eq 0
    end
  end

  it "is refused for a job of the printer's own queue" do
    own_job = create(:printer_job, printer:, name: 'cube.gcode', status: 'active')

    expect_refused(described_class.new(printer_job: own_job, progress: 43), "cube.gcode isn't a copy of a queue entry")
    expect(own_job.reload.progress).to eq 0
  end

  it 'is refused without a job' do
    expect_refused(described_class.new(printer_job: nil, progress: 43), "Printer job can't be blank")
  end
end
