# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::AddToQueue, type: :request do
  include_context 'with a queue mutation'

  let(:file) { create(:file_record) }
  let(:selection) { 'printJob { id copies position held samePrinter }' }

  def add(**input) = mutate('addToQueue', { fileId: file.id, **input }, selection)

  it 'adds one copy of the file, for every printer, at the bottom, and asks for a dispatch pass' do
    create(:print_job, position: 4)

    add

    expect_saved
    job = PrintQueue::Job.last
    expect(data['printJob']).to eq('id' => job.id.to_s, 'copies' => 1, 'position' => 5, 'held' => false,
                                   'samePrinter' => false)
    expect(job).to have_attributes(item: file, all_capable: true, colour: nil)
    expect(dispatch_request).to have_received(:save).once
  end

  it 'adds copies in a colour, on the same printer' do
    add(copies: 3, colour: 'Galaxy Black', samePrinter: true)

    expect_saved
    expect(PrintQueue::Job.last).to have_attributes(copies: 3, colour: 'Galaxy Black', same_printer: true)
  end

  it 'limits it to the printers given' do
    mk4 = create(:printer)
    create(:printer)

    add(printerIds: [mk4.id])

    expect_saved
    expect(PrintQueue::Job.last).to have_attributes(all_capable: false, printers: [mk4])
  end

  it 'is refused for an empty printer list' do
    add(printerIds: [])

    expect_refused('Choose at least one printer')
    expect(data['printJob']).to be_nil
    expect(PrintQueue::Job.count).to eq 0
  end

  it 'is refused for less than one copy, on the copies field' do
    add(copies: 0)

    expect_refused('Copies must be greater than or equal to 1', field: 'copies')
    expect_nothing_pushed
  end

  it 'returns an error for an unknown file' do
    mutate('addToQueue', { fileId: file.id + 1 }, selection)

    expect_refused('File not found')
    expect(data['printJob']).to be_nil
  end
end
