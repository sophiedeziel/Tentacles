# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::PrintStart do
  include_context 'with a queue operation'

  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:job) { create(:print_job, copies: 2) }
  let(:status) { 'enqueued' }
  let(:printer_job) { create(:printer_job, :copy, print_job: job, printer:, status:) }

  def start
    described_class.new(printer_job:).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer_job:) }
  end

  context 'when the copy is enqueued' do
    it 'turns it active, started now' do
      expect(start.errors).to be_empty
      expect(printer_job.reload).to have_attributes(status: 'active',
                                                    started_at: be_within(1.second).of(Time.current))
    end

    it 'keeps the started_at it already has' do
      started = 1.minute.ago.change(usec: 0)
      printer_job.update!(started_at: started)

      expect(start.errors).to be_empty
      expect(printer_job.reload).to have_attributes(status: 'active', started_at: started)
    end

    it "pushes the copy's printer once, without asking for a dispatch pass" do
      start

      expect_pushed_once([printer])
      expect_no_dispatch_requested
    end

    it "is refused when it's cancelled meanwhile, without turning it active" do
      allow(printer_job).to receive(:reload) { printer_job.tap { |copy| copy.status = 'cancelled' } }

      expect_refused(described_class.new(printer_job:), 'Copy 1 of test.gcode has already ended')
      expect(Printer::Job.find(printer_job.id)).to have_attributes(status: 'enqueued', started_at: nil)
    end
  end

  context 'when the copy is cancelled' do
    let(:status) { 'cancelled' }

    it 'is refused, leaving it cancelled' do
      expect_refused(described_class.new(printer_job:), 'Copy 1 of test.gcode has already ended')
      expect(printer_job.reload).to have_attributes(status: 'cancelled', started_at: nil)
    end
  end

  context 'when the copy is under way' do
    let(:status) { 'active' }

    it 'is refused' do
      expect_refused(described_class.new(printer_job:), 'Copy 1 of test.gcode has already started')
      expect(printer_job.reload).to have_attributes(status: 'active', started_at: nil)
    end
  end

  it "is refused for a job of the printer's own queue" do
    own_job = create(:printer_job, printer:, name: 'cube.gcode')

    expect_refused(described_class.new(printer_job: own_job), "cube.gcode isn't a copy of a queue entry")
    expect(own_job.reload).to have_attributes(status: 'enqueued', started_at: nil)
  end

  it 'is refused without a job' do
    expect_refused(described_class.new(printer_job: nil), "Printer job can't be blank")
  end
end
