# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::GcodeReanalysis do
  it 'schedules the G-code files never read, pending or read by an older version, and counts them' do
    never_read = create(:file_record)
    outdated = create(:gcode_summary, :ready, analysis_version: Gcode::Summary::VERSION - 1).item
    stuck = create(:gcode_summary, analysis_version: Gcode::Summary::VERSION).item
    create(:gcode_summary, :ready)
    create(:gcode_summary, :ready, status: 'failed')
    build(:file_record).tap { |item| item.file.attach(io: StringIO.new('solid'), filename: 'a.stl') }.save!
    reanalysis = described_class.new

    expect { reanalysis.save! }.to have_enqueued_job(AnalyseGcodeJob).exactly(3).times
    expect(reanalysis.count).to eq 3
    [never_read, outdated, stuck].each { |item| expect(AnalyseGcodeJob).to have_been_enqueued.with(item.id) }
  end

  it 'counts 0 before it is saved, and when nothing is outdated' do
    create(:gcode_summary, :ready)

    expect(described_class.new.count).to eq 0
    expect(described_class.new.tap(&:save!).count).to eq 0
  end
end
