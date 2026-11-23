# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::FilamentDemand do
  def entry(materials: ['PLA'], **attributes)
    create(:print_job, **attributes).tap do |job|
      create(:gcode_summary, :ready, :with_tools, item: job.item, materials:)
    end
  end

  def demand = described_class.new(entries: PrintQueue::NextJob.candidates)

  it 'counts the waiting entries asking for exactly the material and colour, held ones included' do
    entry(colour: 'White')
    entry(colour: ' white ', held: true)
    entry(colour: 'Black')
    entry(colour: 'White', materials: ['PETG'])
    entry # Any colour: prints with it, but asks for no colour

    expect(demand.count(material: 'PLA', colour: 'White')).to eq 2
    expect(demand.count(material: 'pla', colour: 'WHITE')).to eq 2
    expect(demand.count(material: 'PETG', colour: 'White')).to eq 1
    expect(demand.count(material: 'ABS', colour: 'White')).to eq 0
  end

  it 'leaves out the entries with no copy waiting' do
    done = entry(colour: 'White', copies: 1)
    create(:printer_job, :copy, print_job: done, status: 'active')

    expect(demand.count(material: 'PLA', colour: 'White')).to eq 0
  end

  it 'counts an entry once, by the tool of the slot (tool n uses slot n + 1)' do
    entry(colour: 'White', materials: %w[PLA PLA])
    entry(colour: 'White', materials: %w[PETG PLA])
    entry(colour: 'White', materials: [nil]) # material not known: asks for no exact filament

    expect(demand.count(material: 'PLA', colour: 'White')).to eq 1
    expect(demand.count(material: 'PLA', colour: 'White', slot: 2)).to eq 2
  end

  it 'counts for a loaded filament' do
    entry(colour: 'Galaxy Black')
    filament = build(:printer_loaded_filament, material: 'PLA', colour: 'Galaxy  black', slot: 1)

    expect(demand.count_for(filament)).to eq 1
  end
end
