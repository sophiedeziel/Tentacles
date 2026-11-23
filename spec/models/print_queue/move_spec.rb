# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::Move do
  include_context 'with a queue operation'

  let!(:first) { create(:print_job, position: 1) }
  let!(:second) { create(:print_job, position: 2) }
  let!(:third) { create(:print_job, position: 3) }

  def move(job, to)
    described_class.new(job:, to:).tap(&:save)
  end

  # A finished entry: its only copy is done
  def finished_entry(position)
    create(:print_job, position:, copies: 1).tap do |job|
      create(:printer_job, :copy, print_job: job, status: 'completed')
    end
  end

  def positions(*jobs)
    jobs.map { |job| job.reload.position }
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(job: third, to: 'top') }
  end

  it 'moves an entry to the top and renumbers the others' do
    expect(move(third, 'top').errors).to be_empty
    expect(positions(third, first, second)).to eq [1, 2, 3]
  end

  it 'moves an entry to the bottom' do
    move(first, 'bottom')

    expect(positions(second, third, first)).to eq [1, 2, 3]
  end

  it 'moves an entry to a position' do
    move(third, 2)

    expect(positions(first, third, second)).to eq [1, 2, 3]
  end

  it 'accepts a position given as a string, and a place as a symbol' do
    move(first, '2')
    expect(positions(second, first, third)).to eq [1, 2, 3]

    move(third, :top)
    expect(positions(third, second, first)).to eq [1, 2, 3]
  end

  it 'moves an entry to the bottom for a position past the last one' do
    move(first, 10)

    expect(positions(second, third, first)).to eq [1, 2, 3]
  end

  it 'renumbers gaps 1..n' do
    first.update!(position: 5)
    second.update!(position: 9)
    third.update!(position: 12)

    move(third, 'top')

    expect(positions(third, first, second)).to eq [1, 2, 3]
  end

  it 'leaves the finished entries where they are, and does not count them' do
    finished = finished_entry(2)
    second.update!(position: 3)
    third.update!(position: 4)

    move(third, 2)

    expect(positions(first, third, second)).to eq [1, 2, 3]
    expect(finished.reload.position).to eq 2
  end

  describe 'before another entry' do
    def move_before(job, before)
      described_class.new(job:, before:).tap(&:save)
    end

    it 'moves an entry up, right before it' do
      expect(move_before(third, second).errors).to be_empty
      expect(positions(first, third, second)).to eq [1, 2, 3]
    end

    it 'moves an entry down, right before it' do
      move_before(first, third)

      expect(positions(second, first, third)).to eq [1, 2, 3]
    end

    it 'places it among the entries with copies waiting, past an entry whose copies are all printing' do
      printing = create(:print_job, position: 2, copies: 1)
      create(:printer_job, :copy, print_job: printing, status: 'active')
      second.update!(position: 3)
      third.update!(position: 4)

      move_before(first, third)

      expect(positions(printing, second, first, third)).to eq [1, 2, 3, 4]
    end

    it 'is refused when the other entry is finished' do
      finished = finished_entry(4)

      expect_refused(described_class.new(job: first, before: finished), 'test.gcode is no longer in the queue')
      expect(positions(first, second, third)).to eq [1, 2, 3]
    end

    it 'is refused before itself' do
      expect_refused(described_class.new(job: first, before: first), "Before can't be the entry moved")
    end

    it 'is refused with a place too' do
      expect_refused(described_class.new(job: first, to: 'top', before: third),
                     'Give a place or an entry to go before, not both')
    end
  end

  it 'pushes once, with no printer for an unbound entry, and asks for a dispatch pass' do
    move(third, 'top')

    expect_pushed_once([])
    expect_dispatch_requested
  end

  it 'pushes the printer the entry is bound to' do
    printer = create(:printer)
    third.update!(same_printer: true, bound_printer: printer)

    move(third, 'top')

    expect_pushed_once([printer])
  end

  [0, -1, 'middle', nil, 1.5].each do |to|
    it "is refused to #{to.inspect}" do
      expect_refused(described_class.new(job: third, to:), 'To must be top, bottom or a position from 1')
      expect(positions(first, second, third)).to eq [1, 2, 3]
    end
  end

  it 'is refused for a finished entry' do
    finished = finished_entry(4)

    expect_refused(described_class.new(job: finished, to: 'top'), 'test.gcode is no longer in the queue')
    expect(finished.reload.position).to eq 4
  end

  it 'is refused without an entry' do
    expect_refused(described_class.new(job: nil, to: 'top'), "Job can't be blank")
  end
end
