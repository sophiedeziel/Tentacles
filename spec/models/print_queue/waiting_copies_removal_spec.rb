# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::WaitingCopiesRemoval do
  include_context 'with a queue operation'

  let(:job) { create(:print_job, copies: 6) }

  def copy(status, entry = job)
    create(:printer_job, :copy, print_job: entry, status:, printer: create(:printer))
  end

  def remove(entry = job)
    described_class.new(job: entry).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(job:) }
  end

  context 'with copies done, printing and failed' do
    let!(:printing) { [copy('enqueued'), copy('active')] }

    before do
      copy('completed')
      copy('error')
    end

    it 'keeps only the copies done, printing or failed' do
      removal = remove

      expect(removal.errors).to be_empty
      expect(removal).not_to be_job_deleted
      expect(job.reload).to have_attributes(copies: 4, waiting_count: 0)
      expect(job).to be_unfinished
    end

    it 'never touches a printing copy' do
      remove

      expect(printing.map { |printer_job| printer_job.reload.status }).to eq %w[enqueued active]
    end

    it 'pushes once, without asking for a dispatch pass' do
      remove

      expect_pushed_once([])
      expect_no_dispatch_requested
    end
  end

  it 'pushes the printer the entry is bound to' do
    printer = create(:printer)
    job.update!(same_printer: true, bound_printer: printer)
    copy('active')

    remove

    expect_pushed_once([printer])
  end

  it 'deletes an entry with no copy dispatched, and its printers' do
    job.update!(all_capable: false)
    create(:print_job_printer, job:)

    removal = remove

    expect(removal.errors).to be_empty
    expect(removal).to be_job_deleted
    expect(PrintQueue::Job.exists?(job.id)).to be false
    expect(PrintQueue::JobPrinter.where(print_job_id: job.id)).to be_empty
    expect_pushed_once([])
  end

  it 'is refused when no copy is waiting' do
    job.update!(copies: 2)
    copy('completed')
    copy('active')

    expect_refused(described_class.new(job:), 'test.gcode has no copies waiting')
    expect(job.reload.copies).to eq 2
  end

  it 'is refused for a finished entry' do
    job.update!(copies: 1)
    copy('completed')

    expect_refused(described_class.new(job:), 'test.gcode is no longer in the queue')
  end
end
