# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::Addition do
  include_context 'with a queue operation'

  let(:item) { create(:file_record) }

  def add(**attributes)
    described_class.new(item:, **attributes).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(item:) }
  end

  it 'adds the file at the bottom, with its options, and returns the entry' do
    addition = add(copies: 3, colour: 'Black', same_printer: true)

    expect(addition.errors).to be_empty
    expect(addition.job).to be_persisted
    expect(addition.job).to have_attributes(item:, copies: 3, colour: 'Black', colour_key: 'black', same_printer: true,
                                            all_capable: true, held: false, bound_printer: nil, position: 1)
  end

  it 'appends after the last entry, finished ones included' do
    create(:print_job, position: 4)
    finished = create(:print_job, position: 7, copies: 1)
    create(:printer_job, :copy, print_job: finished, status: 'completed')

    expect(add.job.position).to eq 8
    expect(add.job.position).to eq 9
  end

  it "defaults to one copy, of the G-code's material in any colour, on all capable printers, at the bottom" do
    expect(add.job).to have_attributes(copies: 1, material: nil, colour: nil, all_capable: true, same_printer: false,
                                       held: false)
  end

  it 'asks for a material, as a material key' do
    expect(add(material: 'petg').job.material).to eq 'PETG'
  end

  it 'is refused for a material that is not in the list' do
    expect_refused(described_class.new(item:, material: 'PCTG'), 'Material is not included in the list')
  end

  it 'adds it held' do
    expect(add(held: true).job).to be_held
  end

  describe 'at the top (Next Up)' do
    it 'goes first among the entries still in the queue, which are numbered 1..n again' do
      second = create(:print_job, position: 3)
      third = create(:print_job, position: 8)
      finished = create(:print_job, position: 1, copies: 1)
      create(:printer_job, :copy, print_job: finished, status: 'completed')

      job = add(position: 'top').job

      expect([job, second, third].map { |entry| entry.reload.position }).to eq [1, 2, 3]
      expect(finished.reload.position).to eq 1
    end

    it 'is refused for another place' do
      expect_refused(described_class.new(item:, position: 'middle'), 'Position is not included in the list')
    end
  end

  it 'pushes once, with no printer, and asks for a dispatch pass' do
    add

    expect_pushed_once([])
    expect_dispatch_requested
  end

  context 'when limited to some printers' do
    let(:printers) { create_list(:printer, 2) }

    it 'lists them (ids may be strings, duplicated)' do
      ids = printers.map { |printer| printer.id.to_s }
      job = add(all_capable: false, printer_ids: ids + ids).job

      expect(job.printers).to match_array printers
    end

    it 'is refused without a printer' do
      expect_refused(described_class.new(item:, all_capable: false, printer_ids: []), 'Choose at least one printer')
      expect(PrintQueue::Job.count).to eq 0
    end

    it 'is refused when a printer can never print it, with why' do
      create(:gcode_summary, :ready, :with_tools, item:, materials: ['PLA'])
      mini = create(:printer, name: 'Mini Delta', bed_shape: 'circular', build_diameter: 110)

      expect_refused(described_class.new(item:, all_capable: false, printer_ids: [printers.first.id, mini.id]),
                     "Mini Delta can't print it: Bed too small: needs 123.09 × 130 mm, has a 110 mm round bed")
    end

    it 'is refused when a printer does not print the material asked for' do
      create(:gcode_summary, :ready, :with_tools, item:, materials: ['PLA'])
      printers.first.update!(name: 'Ender 3 V2', materials: ['PLA'])

      expect_refused(described_class.new(item:, material: 'PETG', all_capable: false, printer_ids: [printers.first.id]),
                     "Ender 3 V2 can't print it: Doesn't print PETG (prints PLA)")
    end

    it 'is not refused for a printer whose limits are not known yet (summary pending or failed)' do
      mini = create(:printer, bed_shape: 'circular', build_diameter: 110)
      create(:gcode_summary, :failed, item:)

      expect(add(all_capable: false, printer_ids: [mini.id]).job.printers).to eq [mini]
    end

    it 'is refused when a printer does not exist' do
      expect_refused(described_class.new(item:, all_capable: false, printer_ids: [printers.first.id, 0]),
                     'One of the printers chosen no longer exists')
    end
  end

  it 'ignores the printer ids of an entry for all capable printers' do
    expect(add(printer_ids: [create(:printer).id]).job.job_printers).to be_empty
  end

  it 'is refused for something that is not a library file' do
    expect_refused(described_class.new(item: create(:printer)), 'Item must be a file of the library')
  end

  it 'is refused without a file' do
    expect_refused(described_class.new(item: nil), "Item can't be blank")
  end

  it 'is refused for less than one copy' do
    expect_refused(described_class.new(item:, copies: 0), 'Copies must be greater than or equal to 1')
  end

  it 'is refused for a colour longer than 40 characters' do
    expect_refused(described_class.new(item:, colour: 'x' * 41), 'Colour is too long (maximum is 40 characters)')
  end
end
