# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::UpdatePrintJob, type: :request do
  include_context 'with a queue mutation'

  let(:job) { create(:print_job, copies: 5, position: 3, colour: 'Black') }
  let(:selection) { 'printJob { id copies material colour samePrinter allCapable position held }' }

  before { create(:gcode_summary, :ready, :with_tools, item: job.item, materials: ['PLA']) }

  def update(id = job.id, **input) = mutate('updatePrintJob', { id:, copies: 5, **input }, selection)

  it "sets the print job's options, keeps its place, and asks for a dispatch pass" do
    voron = create(:printer)

    update(copies: 7, material: 'PETG', colour: 'Grey', samePrinter: true, printerIds: [voron.id])

    expect_saved
    expect(data['printJob']).to eq('id' => job.id.to_s, 'copies' => 7, 'material' => 'PETG', 'colour' => 'Grey',
                                   'samePrinter' => true, 'allCapable' => false, 'position' => 3, 'held' => false)
    expect(job.reload.printers).to eq [voron]
    expect(dispatch_request).to have_received(:save).once
  end

  it "takes the defaults for the options omitted: the G-code's material, Any colour, every printer" do
    job.update!(material: 'PETG', all_capable: false, printers: [create(:printer)])

    update

    expect_saved
    expect(data['printJob']).to include('material' => nil, 'colour' => nil, 'samePrinter' => false,
                                        'allCapable' => true)
  end

  it 'is refused below the copies done and printing, with the print job as it is' do
    2.times { create(:printer_job, :copy, print_job: job, status: 'completed') }
    create(:printer_job, :copy, print_job: job, status: 'active')

    update(copies: 2, colour: 'Red')

    expect_refused("Can't go below 3: 2 done and 1 printing")
    expect(data['printJob']).to include('copies' => 5, 'colour' => 'Black')
    expect_nothing_pushed
  end

  it 'is refused for a printer that can never print it, with why' do
    mini = create(:printer, name: 'Mini Delta', bed_shape: 'circular', build_diameter: 110)

    update(printerIds: [mini.id])

    expect_refused("Mini Delta can't print it: Bed too small: needs 123.09 × 130 mm, has a 110 mm round bed")
    expect(job.reload.all_capable).to be true
  end

  it 'is refused while the global queue is off' do
    turn_queue_off

    update(copies: 3)

    expect_refused('The global print queue is off')
    expect(job.reload.copies).to eq 5
  end

  it 'returns an error for an unknown print job' do
    update(job.id + 1)

    expect_refused('Print job not found')
    expect(data['printJob']).to be_nil
  end
end
