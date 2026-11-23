# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::GcodeSummaryScheduling do
  let(:item) { create(:file_record) }

  it 'creates a pending summary and enqueues AnalyseGcodeJob' do
    expect { described_class.new(item:).save! }.to have_enqueued_job(AnalyseGcodeJob).with(item.id)
    expect(item.gcode_summary).to have_attributes(status: 'pending', persisted?: true)
  end

  it 'resets a failed summary to pending, without its error, keeping its values until read again' do
    summary = create(:gcode_summary, :ready, item:, status: 'failed', error: 'Not a G-code text file')

    described_class.new(item:).save!

    expect(summary.reload).to have_attributes(status: 'pending', error: nil, slicer: 'PrusaSlicer')
  end

  it 'takes the row lock, even for a row already pending, to wait for a read in progress' do
    summary = create(:gcode_summary, item:)
    allow(Library::GcodeSummary).to receive(:find_or_create_for!).with(item).and_return(summary)
    allow(summary).to receive(:with_lock).and_call_original

    described_class.new(item:).save!

    expect(summary).to have_received(:with_lock)
  end

  it 'refuses a file that is not G-code' do
    item.file.attach(io: StringIO.new('solid cube'), filename: 'cube.stl')
    scheduling = described_class.new(item:)

    expect { expect(scheduling.save).to be false }.not_to have_enqueued_job(AnalyseGcodeJob)
    expect(scheduling.errors.full_messages).to eq ['Not a G-code file']
    expect(item.gcode_summary).to be_nil
  end
end
