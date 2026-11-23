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

  it 'defaults to one copy, for any colour, on all capable printers' do
    expect(add.job).to have_attributes(copies: 1, colour: nil, all_capable: true, same_printer: false)
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
