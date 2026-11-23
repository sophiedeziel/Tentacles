# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::PrinterBinding do
  include_context 'with a queue operation'

  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:other_printer) { create(:printer, name: 'Ender 3') }
  let(:job) { create(:print_job, copies: 3) }

  def bind(printer: self.printer, on: job)
    described_class.new(job: on, printer:).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(job:, printer:) }
  end

  it 'binds the entry to the printer' do
    expect(bind.errors).to be_empty
    expect(job.reload).to have_attributes(same_printer: true, bound_printer: printer)
  end

  it 'pushes once, the printer bound, without asking for a dispatch pass' do
    bind

    expect_pushed_once([printer])
    expect_no_dispatch_requested
  end

  context 'without a printer' do
    it 'binds the entry at its next dispatch' do
      expect(bind(printer: nil).errors).to be_empty
      expect(job.reload).to have_attributes(same_printer: true, bound_printer: nil)
    end

    it 'pushes once, with no printer, without asking for a dispatch pass' do
      bind(printer: nil)

      expect_pushed_once([])
      expect_no_dispatch_requested
    end
  end

  context 'when the entry is bound to another printer' do
    before { job.update!(same_printer: true, bound_printer: other_printer) }

    it 'binds it to the new printer, pushes both printers once and asks for a dispatch pass' do
      bind

      expect(job.reload.bound_printer).to eq printer
      expect_pushed_once([other_printer, printer])
      expect_dispatch_requested
    end

    it 'unbinds it, without a printer, pushing the previous one and asking for a dispatch pass' do
      bind(printer: nil)

      expect(job.reload).to have_attributes(same_printer: true, bound_printer: nil)
      expect_pushed_once([other_printer])
      expect_dispatch_requested
    end
  end

  it 'does not ask for a dispatch pass when bound to the same printer again' do
    job.update!(same_printer: true, bound_printer: printer)

    bind

    expect_pushed_once([printer])
    expect_no_dispatch_requested
  end

  context 'when the entry is limited to some printers' do
    let(:job) { create(:print_job, all_capable: false) }

    before { create(:print_job_printer, job:, printer: other_printer) }

    it 'binds it to a printer listed' do
      expect(bind(printer: other_printer).errors).to be_empty
      expect(job.reload.bound_printer).to eq other_printer
    end

    it 'is refused for a printer not listed' do
      expect_refused(described_class.new(job:, printer:), "test.gcode can't go to Prusa MK4")
      expect(job.reload).to have_attributes(same_printer: false, bound_printer: nil)
    end
  end

  it 'is refused for a finished entry' do
    finished = create(:print_job, copies: 1)
    create(:printer_job, :copy, print_job: finished, status: 'completed')

    expect_refused(described_class.new(job: finished, printer:), 'test.gcode is no longer in the queue')
  end

  it 'is refused without an entry' do
    expect_refused(described_class.new(job: nil, printer:), "Job can't be blank")
  end
end
