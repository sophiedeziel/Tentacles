# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::BatchPrinter do
  let(:job) { create(:print_job, copies: 5) }
  let(:mk4) { create(:printer, name: 'Prusa MK4') }
  let(:voron) { create(:printer, name: 'Voron 2.4') }

  def copy(status, printer) = create(:printer_job, :copy, print_job: job, status:, printer:)

  def printer(**) = described_class.new(job:, needs: job.needs, **).printer

  it 'is nil when same printer is off' do
    job.update!(same_printer: true, bound_printer: mk4)

    expect(printer(same_printer: false)).to be_nil
  end

  it 'keeps the printer the batch is bound to' do
    job.update!(same_printer: true, bound_printer: mk4)
    copy('active', voron)

    expect(printer(same_printer: true)).to eq mk4
  end

  it 'ignores a binding left over while same printer was off' do
    job.update!(same_printer: false, bound_printer: mk4)

    expect(printer(same_printer: true)).to be_nil
  end

  it 'takes the printer of the latest copy printing, handed over or done' do
    copy('completed', mk4)
    copy('enqueued', voron)
    copy('cancelled', mk4)

    expect(printer(same_printer: true)).to eq voron
  end

  it 'is nil without a copy started' do
    copy('error', mk4)

    expect(printer(same_printer: true)).to be_nil
  end

  it 'lets go of a printer outside the printer list' do
    job.update!(same_printer: true, bound_printer: mk4)

    expect(printer(same_printer: true, all_capable: false, printer_ids: [voron.id])).to be_nil
    expect(printer(same_printer: true, all_capable: false, printer_ids: [mk4.id.to_s])).to eq mk4
  end

  it 'lets go of a printer that can never print it, even when every printer that can print it may' do
    job.update!(same_printer: true, bound_printer: mk4)
    mk4.update!(materials: ['PLA'])
    needs = PrintQueue::Job.new(item: job.item, material: 'PETG').needs

    expect(described_class.new(job:, needs:, same_printer: true).printer).to be_nil
    expect(printer(same_printer: true)).to eq mk4
  end

  it 'is nil for an entry not saved' do
    expect(described_class.new(job: PrintQueue::Job.new, needs: PrintQueue::Needs.new,
                               same_printer: true).printer).to be_nil
  end
end
