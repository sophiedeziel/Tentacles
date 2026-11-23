# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::JobPrinter do
  let(:job_printer) { create(:print_job_printer) }

  it 'has a valid factory' do
    expect(build(:print_job_printer)).to be_valid
  end

  it 'lists a printer once per entry' do
    duplicate = build(:print_job_printer, job: job_printer.job, printer: job_printer.printer)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:printer_id]).to eq ['has already been taken']
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'lists the same printer for another entry' do
    expect(build(:print_job_printer, printer: job_printer.printer)).to be_valid
  end

  it 'is deleted with its entry (the database cascades)' do
    PrintQueue::Job.where(id: job_printer.print_job_id).delete_all

    expect(described_class.exists?(job_printer.id)).to be false
  end
end
