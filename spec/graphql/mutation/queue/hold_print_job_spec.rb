# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::HoldPrintJob, type: :request do
  include_context 'with a queue mutation'

  let(:job) { create(:print_job, copies: 2) }

  def hold(id = job.id) = mutate('holdPrintJob', { id: }, 'printJob { id held }')

  it 'holds the print job and returns it' do
    hold

    expect_saved
    expect(data['printJob']).to eq('id' => job.id.to_s, 'held' => true)
    expect(job.reload.held).to be true
  end

  it 'is refused for a print job no longer in the queue' do
    job.update!(copies: 1)
    create(:printer_job, :copy, print_job: job, status: 'completed')

    hold

    expect_refused('test.gcode is no longer in the queue')
    expect(data['printJob']).to eq('id' => job.id.to_s, 'held' => false)
    expect_nothing_pushed
  end

  it 'returns an error for an unknown print job' do
    hold(job.id + 1)

    expect_refused('Print job not found')
    expect(data['printJob']).to be_nil
  end
end
