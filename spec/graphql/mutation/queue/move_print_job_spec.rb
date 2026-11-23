# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::MovePrintJob, type: :request do
  include_context 'with a queue mutation'

  let!(:first) { create(:print_job, position: 1) }
  let!(:second) { create(:print_job, position: 2) }
  let!(:third) { create(:print_job, position: 3) }

  def move(job, **input)
    mutate('movePrintJob', { id: job.id, **input }, 'printJob { id position } globalQueue { waiting { id } }')
  end

  def ids(*jobs) = jobs.map { |job| { 'id' => job.id.to_s } }

  def order = PrintQueue::Job.in_queue_order.to_a

  it 'moves a print job to the top and returns the new order' do
    move(third, to: 'TOP')

    expect_saved
    expect(data['printJob']).to eq('id' => third.id.to_s, 'position' => 1)
    expect(data['globalQueue']['waiting']).to eq ids(third, first, second)
    expect(order).to eq [third, first, second]
    expect(dispatch_request).to have_received(:save).once
  end

  it 'moves a print job to the bottom' do
    move(first, to: 'BOTTOM')

    expect_saved
    expect(order).to eq [second, third, first]
  end

  it 'moves a print job right before another one' do
    move(first, beforeId: third.id)

    expect_saved
    expect(data['printJob']).to eq('id' => first.id.to_s, 'position' => 2)
    expect(order).to eq [second, first, third]
  end

  it 'is refused without a place' do
    move(first)

    expect_refused('To must be top, bottom or a position from 1', field: 'to')
    expect(order).to eq [first, second, third]
    expect_nothing_pushed
  end

  it 'is refused with both a place and a print job to go before' do
    move(first, to: 'TOP', beforeId: third.id)

    expect_refused('Give a place or an entry to go before, not both')
  end

  it 'is refused before itself' do
    move(first, beforeId: first.id)

    expect_refused("Before can't be the entry moved", field: 'before')
  end

  it 'is refused before a print job no longer in the queue' do
    finished = create(:print_job, position: 4, copies: 1)
    create(:printer_job, :copy, print_job: finished, status: 'completed')

    move(first, beforeId: finished.id)

    expect_refused('test.gcode is no longer in the queue')
    expect(data['printJob']).to eq('id' => first.id.to_s, 'position' => 1)
    expect(order).to eq [first, second, third, finished]
  end

  it 'is refused for a print job no longer in the queue' do
    first.update!(copies: 1)
    create(:printer_job, :copy, print_job: first, status: 'completed')

    move(first, to: 'BOTTOM')

    expect_refused('test.gcode is no longer in the queue')
  end

  it 'is refused while the global queue is off' do
    turn_queue_off

    move(third, to: 'TOP')

    expect_refused('The global print queue is off')
    expect(data['globalQueue']).to be_nil
    expect(order).to eq [first, second, third]
  end

  it 'returns an error for an unknown print job' do
    mutate('movePrintJob', { id: third.id + 1, to: 'TOP' }, 'printJob { id }')

    expect_refused('Print job not found')
    expect(data['printJob']).to be_nil
  end

  it 'returns an error for an unknown print job to go before' do
    move(first, beforeId: third.id + 1)

    expect_refused('The print job to move it before was not found', field: 'beforeId')
    expect(order).to eq [first, second, third]
  end
end
