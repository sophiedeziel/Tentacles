# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::GcodeSummary::Failure do
  let(:gcode_summary) { create(:gcode_summary, :ready, analysis_version: 0, filament_changes: [{ 'line' => 1 }]) }

  it 'marks the summary failed with its message, clearing its values and tools' do
    create(:gcode_summary_tool, gcode_summary:)

    described_class.new(gcode_summary:, message: 'Not a G-code text file').save!

    expect(gcode_summary.reload).to have_attributes(
      status: 'failed', error: 'Not a G-code text file', analysis_version: Gcode::Summary::VERSION, slicer: nil,
      print_seconds: nil, min_x: nil, footprint_source: nil, tool_count: nil, tool_changes: nil, filament_changes: []
    )
    expect(gcode_summary.tools).to be_empty
  end

  it 'cuts a long message to the column' do
    described_class.new(gcode_summary:, message: 'x' * 300).save!

    expect(gcode_summary.reload.error.length).to eq 255
  end

  it 'needs a message' do
    expect(described_class.new(gcode_summary:).save).to be false
  end
end
