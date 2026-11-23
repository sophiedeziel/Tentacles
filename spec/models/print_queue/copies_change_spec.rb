# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::CopiesChange do
  include_context 'with a queue operation'

  let(:job) { create(:print_job, copies: 5, position: 1) }

  def copy(status, entry = job)
    create(:printer_job, :copy, print_job: entry, status:, printer: create(:printer))
  end

  def change(copies, entry = job)
    described_class.new(job: entry, copies:).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(job:, copies: 6) }
  end

  it 'raises the copies and asks for a dispatch pass' do
    expect(change(7).errors).to be_empty
    expect(job.reload.copies).to eq 7
    expect_pushed_once([])
    expect_dispatch_requested
  end

  it 'lowers the copies without asking for a dispatch pass' do
    expect(change(2).errors).to be_empty
    expect(job.reload.copies).to eq 2
    expect_pushed_once([])
    expect_no_dispatch_requested
  end

  it 'pushes the printer the entry is bound to' do
    printer = create(:printer)
    job.update!(same_printer: true, bound_printer: printer)

    change(6)

    expect_pushed_once([printer])
  end

  context 'with copies done and printing' do
    before do
      2.times { copy('completed') }
      copy('active')
    end

    it 'is refused below the copies done or printing' do
      expect_refused(described_class.new(job:, copies: 2), "Can't go below 3: 2 done and 1 printing")
      expect(job.reload.copies).to eq 5
    end

    it 'goes down to the copies done or printing' do
      expect(change(3).errors).to be_empty
      expect(job.reload).to have_attributes(copies: 3, waiting_count: 0)
    end
  end

  it 'names only the counts there are' do
    copy('enqueued')
    copy('active')

    expect_refused(described_class.new(job:, copies: 1), "Can't go below 2: 2 printing")
  end

  it 'does not count the failed copies toward the floor' do
    job.update!(copies: 3)
    copy('completed')
    copy('error')
    copy('cancelled')

    expect(change(1).errors).to be_empty
    expect(job.reload.copies).to eq 1
  end

  it 'is refused below one copy' do
    expect_refused(described_class.new(job:, copies: 0), 'Copies must be greater than or equal to 1')
  end

  context 'when the entry is finished' do
    let(:job) { create(:print_job, copies: 2, position: 1) }

    before do
      copy('completed')
      copy('error')
      create(:print_job, position: 5)
    end

    it 'puts it back in the queue, at the bottom, when raised' do
      expect(change(3).errors).to be_empty
      expect(job.reload).to have_attributes(copies: 3, position: 6, waiting_count: 1)
      expect(job).to be_unfinished
      expect_dispatch_requested
    end

    it 'keeps its position when lowered' do
      expect(change(1).errors).to be_empty
      expect(job.reload).to have_attributes(copies: 1, position: 1)
      expect(job).not_to be_unfinished
    end
  end

  it 'checks the floor again under the queue lock' do
    job.update!(copies: 3)
    2.times { copy('completed') }
    # A copy is dispatched between the validation and the write
    allow(job).to receive(:reload).and_wrap_original do |original, *args|
      copy('active')
      original.call(*args)
    end

    expect_refused(described_class.new(job:, copies: 2), "Can't go below 3: 2 done and 1 printing")
    expect(PrintQueue::Job.find(job.id).copies).to eq 3
  end
end
