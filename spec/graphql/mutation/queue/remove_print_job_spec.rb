# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::RemovePrintJob, type: :request do
  include_context 'with a queue mutation'

  let(:job) { create(:print_job, copies: 4) }

  def remove(id = job.id) = mutate('removePrintJob', { id: }, 'printJob { id copies } deletedPrintJobId')

  def copy(status) = create(:printer_job, :copy, print_job: job, status:)

  it 'removes the waiting copies and keeps the print job while a copy prints' do
    copy('completed')
    copy('active')

    remove

    expect_saved
    expect(data['printJob']).to eq('id' => job.id.to_s, 'copies' => 2)
    expect(data['deletedPrintJobId']).to be_nil
    expect(job.reload.copies).to eq 2
  end

  it 'deletes a print job with no copy handed to a printer, and returns its id' do
    remove

    expect_saved
    expect(data['printJob']).to be_nil
    expect(data['deletedPrintJobId']).to eq job.id.to_s
    expect(PrintQueue::Job.exists?(job.id)).to be false
  end

  it 'is refused when no copy is waiting' do
    job.update!(copies: 1)
    copy('active')

    remove

    expect_refused('test.gcode has no copies waiting')
    expect(data['printJob']).to eq('id' => job.id.to_s, 'copies' => 1)
    expect_nothing_pushed
  end

  it 'returns an error for an unknown print job' do
    remove(job.id + 1)

    expect_refused('Print job not found')
    expect(data['printJob']).to be_nil
    expect(data['deletedPrintJobId']).to be_nil
  end
end
