# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::UnbindPrintJob, type: :request do
  include_context 'with a queue mutation'

  let(:printer) { create(:printer) }
  let(:job) { create(:print_job, copies: 3, same_printer: true, bound_printer: printer) }

  def unbind(id = job.id) = mutate('unbindPrintJob', { id: }, 'printJob { id samePrinter boundPrinter { id } }')

  it 'lets the copies go to any printer, pushes the printer it was bound to and asks for a dispatch pass' do
    unbind

    expect_saved
    expect(data['printJob']).to eq('id' => job.id.to_s, 'samePrinter' => false, 'boundPrinter' => nil)
    expect(job.reload).to have_attributes(same_printer: false, bound_printer: nil)
    expect(TentaclesSchema.subscriptions).to have_received(:trigger).with(:print_queue_changed, {}, printer)
    expect(dispatch_request).to have_received(:save).once
  end

  it 'is refused for a print job no longer in the queue' do
    job.update!(copies: 1)
    create(:printer_job, :copy, print_job: job, printer:, status: 'completed')

    unbind

    expect_refused('test.gcode is no longer in the queue')
    expect(data['printJob']).to eq('id' => job.id.to_s, 'samePrinter' => true,
                                   'boundPrinter' => { 'id' => printer.id.to_s })
    expect_nothing_pushed
  end

  it 'is refused while the global queue is off' do
    turn_queue_off

    unbind

    expect_refused('The global print queue is off')
    expect(job.reload.bound_printer).to eq printer
  end

  it 'returns an error for an unknown print job' do
    unbind(job.id + 1)

    expect_refused('Print job not found')
    expect(data['printJob']).to be_nil
  end
end
