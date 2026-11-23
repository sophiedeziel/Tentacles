# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Sweep do
  let(:dispatch) { instance_spy(PrintQueue::Dispatch, save!: true) }
  let(:entry) { create(:print_job, copies: 5) }

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    allow(PrintQueue::Dispatch).to receive(:new).and_return(dispatch)
  end

  def sweep
    described_class.new.tap(&:save!)
  end

  it 'runs a dispatch pass, then lists the printers with an enqueued copy' do
    enqueued = create(:printer_job, :copy, print_job: entry, status: 'enqueued')
    create(:printer_job, :copy, print_job: entry, status: 'active')
    create(:printer_job, :copy, print_job: entry, status: 'completed')
    create(:printer_job, status: 'enqueued') # a job of the printer's own queue

    expect(sweep.printer_ids).to eq [enqueued.printer_id]
    expect(dispatch).to have_received(:save!).once
  end

  it 'lists a printer once' do
    printer = create(:printer)
    create_list(:printer_job, 2, :copy, print_job: entry, printer:)

    expect(sweep.printer_ids).to eq [printer.id]
  end

  it 'still lists the printers when the queue is busy' do
    allow(dispatch).to receive(:save!).and_raise(ActiveRecord::LockWaitTimeout, 'Lock wait timeout exceeded')
    allow(Rails.logger).to receive(:warn)
    enqueued = create(:printer_job, :copy, print_job: entry)

    expect(sweep.printer_ids).to eq [enqueued.printer_id]
    expect(Rails.logger).to have_received(:warn).with(/Dispatch pass skipped: ActiveRecord::LockWaitTimeout/)
  end

  it 'raises the other errors of the pass' do
    allow(dispatch).to receive(:save!).and_raise(ActiveRecord::StatementInvalid, 'Lost connection')

    expect { sweep }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it 'does nothing while the global queue is off' do
    allow(PrintQueue).to receive(:enabled?).and_return(false)
    create(:printer_job, :copy, print_job: entry)

    expect(sweep.printer_ids).to be_empty
    expect(PrintQueue::Dispatch).not_to have_received(:new)
  end
end
