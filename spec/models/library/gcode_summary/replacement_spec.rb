# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::GcodeSummary::Replacement do
  let(:gcode_summary) { create(:gcode_summary, analysis_version: 0) }
  let(:summary) do
    Gcode::Summary.new(slicer: 'Cura', print_seconds: 60, min_x: 1, max_x: 2, min_y: 3, max_y: 4,
                       footprint_source: 'slicer', filament_changes: [{ 'line' => 9, 'z' => 1.2, 'layer' => nil }],
                       tools: [Gcode::Summary::Tool.new(tool: 0, material: 'PLA', millimetres: 100),
                               Gcode::Summary::Tool.new(tool: 1, material_raw: 'PCTG')])
  end

  it 'writes the values and the tools, and marks the summary ready, read by the current version' do
    create(:gcode_summary_tool, gcode_summary:, tool: 3)

    described_class.new(gcode_summary:, summary:).save!

    expect(gcode_summary.reload).to have_attributes(
      status: 'ready', error: nil, analysis_version: Gcode::Summary::VERSION, slicer: 'Cura', print_seconds: 60,
      footprint_source: 'slicer', analysed_at: be_within(1.second).of(Time.current),
      filament_changes: [{ 'line' => 9, 'z' => 1.2, 'layer' => nil }]
    )
    expect(gcode_summary.tools.map { |tool| [tool.tool, tool.material, tool.material_raw, tool.millimetres] })
      .to eq [[0, 'PLA', nil, 100], [1, nil, 'PCTG', nil]]
  end

  it 'writes in one transaction: a failed write keeps the values before' do
    create(:gcode_summary_tool, gcode_summary:)
    allow(Library::GcodeSummary::Tool).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { described_class.new(gcode_summary:, summary:).save! }.to raise_error(ActiveRecord::StatementInvalid)
    expect(gcode_summary.reload).to have_attributes(status: 'pending', slicer: nil)
    expect(gcode_summary.tools.size).to eq 1
  end

  it 'needs a summary and what it read' do
    expect(described_class.new(gcode_summary:).save).to be false
    expect(described_class.new(summary:).save).to be false
  end
end
