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

  it 'adds copies in a material and a colour, on the same printer' do
    add(copies: 3, material: 'PETG', colour: 'Galaxy Black', samePrinter: true)

    expect_saved
    expect(PrintQueue::Job.last).to have_attributes(copies: 3, material: 'PETG', colour: 'Galaxy Black',
                                                    same_printer: true)
  end

  it 'adds it at the top (Next Up), held' do
    other = create(:print_job, position: 1)

    add(position: 'TOP', held: true)

    expect_saved
    expect(data['printJob']).to include('position' => 1, 'held' => true)
    expect(other.reload.position).to eq 2
  end

  it 'is refused for a material that is not in the list, on the material field' do
    add(material: 'PCTG')

    expect_refused('Material is not included in the list', field: 'material')
  end

  describe 'hard limits' do
    let(:mini) { create(:printer, name: 'Mini Delta', bed_shape: 'circular', build_diameter: 110) }

    it 'refuses a printer list naming a printer that can never print it, with why' do
      create(:gcode_summary, :ready, :with_tools, item: file, materials: ['PLA'])

      add(printerIds: [create(:printer).id, mini.id])

      expect_refused("Mini Delta can't print it: Bed too small: needs 123.09 × 130 mm, has a 110 mm round bed")
      expect(PrintQueue::Job.count).to eq 0
      expect_nothing_pushed
    end

    it 'leaves that printer out, without refusing, for every printer that can print it' do
      create(:gcode_summary, :ready, :with_tools, item: file, materials: ['PLA'])
      mini

      add

      expect_saved
      expect(PrintQueue::Job.last.all_capable).to be true
    end

    it 'refuses nothing while the summary is pending: its values are not known yet' do
      create(:gcode_summary, item: file, status: 'pending')

      add(printerIds: [mini.id])

      expect_saved
      expect(PrintQueue::Job.last.printers).to eq [mini]
    end

    context 'when the summary failed' do
      before do
        create(:gcode_summary, :failed, item: file)
        mini.update!(materials: ['PLA'])
      end

      it 'refuses nothing: its values are not known' do
        add(printerIds: [mini.id])

        expect_saved
      end

      it 'still refuses a printer that does not print the material asked for' do
        add(printerIds: [mini.id], material: 'PETG')

        expect_refused("Mini Delta can't print it: Doesn't print PETG (prints PLA)")
      end
    end
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

  it 'is refused for a printer that does not exist' do
    add(printerIds: [create(:printer).id + 1])

    expect_refused('One of the printers chosen no longer exists')
  end

  it 'is refused for less than one copy, on the copies field' do
    add(copies: 0)

    expect_refused('Copies must be greater than or equal to 1', field: 'copies')
    expect_nothing_pushed
  end

  it 'is refused while the global queue is off' do
    turn_queue_off

    add

    expect_refused('The global print queue is off')
    expect(PrintQueue::Job.count).to eq 0
  end

  it 'returns an error for an unknown file' do
    mutate('addToQueue', { fileId: file.id + 1 }, selection)

    expect_refused('File not found')
    expect(data['printJob']).to be_nil
  end
end
