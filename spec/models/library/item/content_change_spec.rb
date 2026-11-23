# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::Item::ContentChange do
  let(:item) { create(:file_record) }

  it 'replaces the content and keeps the name' do
    described_class.new(item:, content: 'new_content').save!

    expect(item.reload).to have_attributes(file_content: 'new_content', filename: 'test.gcode')
  end

  it 'renames the file when given a name' do
    described_class.new(item:, content: 'G1 X1', filename: 'cube.gcode').save!

    expect(item.reload.filename).to eq 'cube.gcode'
  end

  it 'accepts an empty content' do
    expect(described_class.new(item:, content: '').save).to be true
    expect(item.reload.file_content).to eq ''
  end

  it 'refuses a missing content' do
    change = described_class.new(item:, content: nil)

    expect(change.save).to be false
    expect(change.errors.full_messages).to eq ["Content can't be blank"]
  end

  it 'resets the G-code summary to pending and schedules reading it again' do
    summary = create(:gcode_summary, :ready, item:)

    expect { described_class.new(item:, content: 'G1 X1 E1').save! }
      .to have_enqueued_job(AnalyseGcodeJob).with(item.id)
    expect(summary.reload).to have_attributes(status: 'pending', slicer: 'PrusaSlicer')
  end

  it 'schedules nothing for a file that is not G-code' do
    item.file.attach(io: StringIO.new('solid'), filename: 'cube.stl')

    expect { described_class.new(item:, content: 'solid cube').save! }.not_to have_enqueued_job(AnalyseGcodeJob)
  end

  context 'when the file is in the print queue' do
    let!(:entry) { create(:print_job, item:, copies: 1) }
    let(:message) { "test.gcode is in the print queue: it can't be changed until its copies are done or removed" }

    it 'is refused, whether the global queue is on or off, leaving the file as it was' do
      [true, false].each do |enabled|
        allow(PrintQueue).to receive(:enabled?).and_return(enabled)
        change = described_class.new(item:, content: 'G1 X1 E1')

        expect { expect(change.save).to be false }.not_to have_enqueued_job(AnalyseGcodeJob)
        expect(change.errors[:base]).to eq [message]
        expect(item.reload.file_content).not_to eq 'G1 X1 E1'
      end
    end

    it 'is refused while a copy is printing' do
      create(:printer_job, :copy, print_job: entry, status: 'active')

      expect(described_class.new(item:, content: 'G1 X1 E1').save).to be false
    end

    it 'is allowed once the entry is finished' do
      create(:printer_job, :copy, print_job: entry, status: 'completed')

      expect(described_class.new(item:, content: 'G1 X1 E1').save).to be true
      expect(item.reload.file_content).to eq 'G1 X1 E1'
    end
  end
end
