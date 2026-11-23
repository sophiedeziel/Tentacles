# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::ReleasePrintJob, type: :request do
  include_context 'with a queue mutation'

  let(:job) { create(:print_job, held: true) }

  def release(id = job.id) = mutate('releasePrintJob', { id: }, 'printJob { id held }')

  it 'releases the print job, returns it and asks for a dispatch pass' do
    release

    expect_saved
    expect(data['printJob']).to eq('id' => job.id.to_s, 'held' => false)
    expect(job.reload.held).to be false
    expect(dispatch_request).to have_received(:save).once
  end

  it 'is refused for a print job no longer in the queue' do
    create(:printer_job, :copy, print_job: job, status: 'completed')

    release

    expect_refused('test.gcode is no longer in the queue')
    expect(data['printJob']).to eq('id' => job.id.to_s, 'held' => true)
    expect_nothing_pushed
  end

  it 'returns an error for an unknown print job' do
    release(job.id + 1)

    expect_refused('Print job not found')
    expect(data['printJob']).to be_nil
  end
end
