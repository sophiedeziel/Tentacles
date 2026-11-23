# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::CopyCancellation do
  include_context 'with a queue operation'

  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:job) { create(:print_job, copies: 2) }
  let(:status) { 'enqueued' }
  let(:printer_job) { create(:printer_job, :copy, print_job: job, printer:, status:) }
  # The printer, played by the fake connector: it accepts the cancel unless given a refusal
  let(:connector) { PrintQueue::Connector::Fake.new }

  before { PrintQueue.connector = connector }

  def cancel
    described_class.new(printer_job:).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer_job:) }
  end

  context 'when the copy is enqueued' do
    it 'ends it cancelled, without asking the printer' do
      expect(cancel.errors).to be_empty
      expect(printer_job.reload).to have_attributes(status: 'cancelled',
                                                    finished_at: be_within(1.second).of(Time.current))
      expect(printer_job.cancel_requested_at).to eq printer_job.finished_at
      expect(connector.commands).to be_empty
    end

    it 'counts it as failed: it uses up its copy' do
      cancel

      expect(job.reload).to have_attributes(failed_count: 1, printing_count: 0, waiting_count: 1)
    end

    it "pushes the copy's printer once and asks for a dispatch pass" do
      cancel

      expect_pushed_once([printer])
      expect_dispatch_requested
    end

    it 'is refused when its spool started it meanwhile, leaving it to be cancelled again' do
      allow(printer_job).to receive(:reload) { printer_job.tap { |copy| copy.status = 'active' } }

      expect_refused(described_class.new(printer_job:),
                     'Copy 1 of test.gcode has just started, cancel it again to stop its print')
      expect(printer_job.cancel_requested_at).to be_nil
      expect(connector.commands).to be_empty
    end
  end

  context 'when the copy is under way' do
    let(:status) { 'active' }

    it 'asks the printer to cancel its print (the connector), leaving the copy active for the print ended handler' do
      expect(cancel.errors).to be_empty
      expect(printer_job.reload).to have_attributes(status: 'active', finished_at: nil,
                                                    cancel_requested_at: be_within(1.second).of(Time.current))
      expect(connector.received(:cancel)).to eq [printer_job]
    end

    it 'keeps when the cancellation was first asked' do
      asked = 1.minute.ago.change(usec: 0)
      printer_job.update!(cancel_requested_at: asked)

      expect(cancel.errors).to be_empty
      expect(printer_job.reload.cancel_requested_at).to eq asked
      expect(connector.received(:cancel)).to eq [printer_job]
    end

    it "pushes the copy's printer once, without asking for a dispatch pass" do
      cancel

      expect_pushed_once([printer])
      expect_no_dispatch_requested
    end

    it "is refused with the printer's message when the printer refuses or fails" do
      connector.refusal = 'Prusa MK4 is no longer printing'

      expect_refused(described_class.new(printer_job:), 'Prusa MK4 is no longer printing')
      expect(printer_job.reload).to have_attributes(status: 'active', cancel_requested_at: nil)
    end
  end

  %w[completed error cancelled].each do |finished|
    context "when the copy is #{finished}" do
      let(:status) { finished }

      it 'is refused' do
        expect_refused(described_class.new(printer_job:), 'Copy 1 of test.gcode has already ended')
        expect(printer_job.reload.status).to eq finished
        expect(connector.commands).to be_empty
      end
    end
  end

  it "is refused for a job of the printer's own queue" do
    own_job = create(:printer_job, printer:, name: 'cube.gcode')

    expect_refused(described_class.new(printer_job: own_job), "cube.gcode isn't a copy of a queue entry")
    expect(own_job.reload.status).to eq 'enqueued'
  end

  it 'is refused without a job' do
    expect_refused(described_class.new(printer_job: nil), "Printer job can't be blank")
  end
end
