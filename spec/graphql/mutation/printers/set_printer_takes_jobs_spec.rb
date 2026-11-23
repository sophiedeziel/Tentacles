# frozen_string_literal: true

require 'rails_helper'
require_relative '../queue/queue_mutation_context'

RSpec.describe Mutations::Printers::SetPrinterTakesJobs, type: :request do
  include_context 'with a queue mutation'

  let(:printer) { create(:printer) }

  def set_takes_jobs(takes_jobs, printer_id = printer.id)
    mutate('setPrinterTakesJobs', { printerId: printer_id, takesJobs: takes_jobs }, 'printer { id takesJobs }')
  end

  it 'stops the printer taking jobs and pushes its queue' do
    set_takes_jobs(false)

    expect_saved
    expect(data['printer']).to eq('id' => printer.id.to_s, 'takesJobs' => false)
    expect(printer.reload.takes_jobs).to be false
    expect(TentaclesSchema.subscriptions).to have_received(:trigger).with(:print_queue_changed, {}, printer)
    expect(dispatch_request).not_to have_received(:save)
  end

  it 'is refused while the global queue is off' do
    turn_queue_off

    set_takes_jobs(false)

    expect_refused('The global print queue is off')
    expect(data['printer']).to eq('id' => printer.id.to_s, 'takesJobs' => true)
    expect_nothing_pushed
  end

  it 'returns the printer as saved and its errors when it is invalid' do
    printer.update_column(:bed_shape, 'hexagonal') # rubocop:disable Rails/SkipsModelValidations

    set_takes_jobs(false)

    expect_refused('Validation failed: Bed shape is not included in the list')
    expect(data['printer']).to eq('id' => printer.id.to_s, 'takesJobs' => true)
  end

  it 'returns an error for an unknown printer' do
    set_takes_jobs(false, printer.id + 1)

    expect_refused('Printer not found')
    expect(data['printer']).to be_nil
  end
end
