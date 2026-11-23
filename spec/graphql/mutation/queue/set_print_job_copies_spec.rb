# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::SetPrintJobCopies, type: :request do
  include_context 'with a queue mutation'

  let(:job) { create(:print_job, copies: 5) }

  def set_copies(copies, id = job.id)
    mutate('setPrintJobCopies', { id:, copies: }, 'printJob { id copies copiesLeftToStart }')
  end

  def copy(status) = create(:printer_job, :copy, print_job: job, status:)

  it 'changes the copies and returns the print job' do
    copy('completed')

    set_copies(3)

    expect_saved
    expect(data['printJob']).to eq('id' => job.id.to_s, 'copies' => 3, 'copiesLeftToStart' => 2)
    expect(job.reload.copies).to eq 3
  end

  it 'is refused below the copies done and printing, with how many of each' do
    2.times { copy('completed') }
    copy('active')

    set_copies(2)

    expect_refused("Can't go below 3: 2 done and 1 printing")
    expect(data['printJob']).to eq('id' => job.id.to_s, 'copies' => 5, 'copiesLeftToStart' => 2)
    expect(job.reload.copies).to eq 5
    expect_nothing_pushed
  end

  it 'keeps every copy on the same printer (Print More Copies)' do
    mutate('setPrintJobCopies', { id: job.id, copies: 6, samePrinter: true }, 'printJob { copies samePrinter }')

    expect_saved
    expect(data['printJob']).to eq('copies' => 6, 'samePrinter' => true)
  end

  it 'lets a bound batch go to any printer' do
    job.update!(same_printer: true, bound_printer: create(:printer))

    mutate('setPrintJobCopies', { id: job.id, copies: 6, samePrinter: false },
           'printJob { samePrinter boundPrinter { id } }')

    expect_saved
    expect(data['printJob']).to eq('samePrinter' => false, 'boundPrinter' => nil)
  end

  it 'is refused below 1, on the copies field' do
    set_copies(0)

    expect_refused('Copies must be greater than or equal to 1', field: 'copies')
    expect(job.reload.copies).to eq 5
  end

  it 'is refused while the global queue is off' do
    turn_queue_off

    set_copies(3)

    expect_refused('The global print queue is off')
    expect(job.reload.copies).to eq 5
  end

  it 'returns an error for an unknown print job' do
    set_copies(3, job.id + 1)

    expect_refused('Print job not found')
    expect(data['printJob']).to be_nil
  end
end
