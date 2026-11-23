# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::PrintEnd do
  include_context 'with a queue operation'

  let(:clears_own_bed) { false }
  let(:printer) { create(:printer, name: 'Prusa MK4', clears_own_bed:) }
  let(:job) { create(:print_job, copies: 2) }
  let(:status) { 'active' }
  let(:printer_job) do
    create(:printer_job, :copy, print_job: job, printer:, status:, started_at: 1.hour.ago)
  end

  def finish(result = 'completed')
    described_class.new(printer_job:, result:).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer_job:, result: 'completed') }
  end

  context 'when the copy is under way' do
    %w[completed error cancelled].each do |result|
      it "ends it #{result}, finished now" do
        expect(finish(result).errors).to be_empty
        expect(printer_job.reload).to have_attributes(status: result,
                                                      finished_at: be_within(1.second).of(Time.current))
      end
    end

    %w[completed error].each do |result|
      it "ends it cancelled when its cancellation was asked, though its print is #{result}" do
        printer_job.update!(cancel_requested_at: 1.minute.ago)

        expect(finish(result).errors).to be_empty
        expect(printer_job.reload).to have_attributes(status: 'cancelled',
                                                      finished_at: be_within(1.second).of(Time.current))
      end
    end

    it "pushes the copy's printer once, then asks for a dispatch pass" do
      calls = []
      allow(PrintQueue).to receive(:push_changed) { calls << :push }
      allow(dispatch_request).to receive(:save) { calls << :dispatch }

      finish

      expect_pushed_once([printer])
      expect_dispatch_requested
      expect(calls).to eq %i[push dispatch]
    end

    it 'is refused when it already ended, changing nothing' do
      finish
      ended = printer_job.reload.attributes

      expect(finish('error').errors[:base]).to eq ['Copy 1 of test.gcode has already ended']
      expect(printer_job.reload.attributes).to eq ended
      expect(printer_job.status).to eq 'completed'
      expect_pushed_once([printer])
      expect_dispatch_requested
    end
  end

  context 'when the printer clears its own bed' do
    let(:clears_own_bed) { true }

    it 'clears the bed of a completed print' do
      finish('completed')

      expect(printer_job.reload).to have_attributes(bed_cleared_at: be_within(1.second).of(Time.current),
                                                    bed_cleared_by: 'automatic')
      expect(printer.bed_needs_clearing?).to be false
    end

    %w[error cancelled].each do |result|
      it "leaves an #{result} print on the bed" do
        finish(result)

        expect(printer_job.reload).to have_attributes(bed_cleared_at: nil, bed_cleared_by: nil)
        expect(printer.bed_needs_clearing?).to be true
      end
    end

    it 'leaves the print on the bed when its cancellation was asked' do
      printer_job.update!(cancel_requested_at: 1.minute.ago)

      finish('completed')

      expect(printer_job.reload).to have_attributes(status: 'cancelled', bed_cleared_at: nil)
      expect(printer.bed_needs_clearing?).to be true
    end
  end

  context "when the printer doesn't clear its own bed" do
    it 'leaves a completed print on the bed' do
      finish('completed')

      expect(printer_job.reload).to have_attributes(bed_cleared_at: nil, bed_cleared_by: nil)
      expect(printer.bed_needs_clearing?).to be true
    end
  end

  context 'when the copy is enqueued' do
    let(:status) { 'enqueued' }

    it 'is refused' do
      expect_refused(described_class.new(printer_job:, result: 'completed'), "Copy 1 of test.gcode hasn't started")
      expect(printer_job.reload).to have_attributes(status: 'enqueued', finished_at: nil)
    end
  end

  it 'is refused with an unknown result' do
    expect_refused(described_class.new(printer_job:, result: 'exploded'), 'Result is not included in the list')
    expect(printer_job.reload).to have_attributes(status: 'active', finished_at: nil)
  end

  it "is refused for a job of the printer's own queue" do
    own_job = create(:printer_job, printer:, name: 'cube.gcode', status: 'active')

    expect_refused(described_class.new(printer_job: own_job, result: 'completed'),
                   "cube.gcode isn't a copy of a queue entry")
    expect(own_job.reload).to have_attributes(status: 'active', finished_at: nil)
  end

  it 'is refused without a job' do
    expect_refused(described_class.new(printer_job: nil, result: 'completed'), "Printer job can't be blank")
  end
end
