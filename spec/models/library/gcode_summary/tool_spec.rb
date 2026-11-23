# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::GcodeSummary::Tool do
  it 'has a valid factory' do
    expect(build(:gcode_summary_tool)).to be_valid
  end

  it 'is one row per tool of a summary' do
    tool = create(:gcode_summary_tool, tool: 0)

    expect(build(:gcode_summary_tool, gcode_summary: tool.gcode_summary, tool: 0)).not_to be_valid
    expect(build(:gcode_summary_tool, gcode_summary: tool.gcode_summary, tool: 1)).to be_valid
    row = { gcode_summary_id: tool.gcode_summary_id, tool: 0, created_at: Time.current, updated_at: Time.current }
    # rubocop:disable-next Rails/SkipsModelValidations -- past the validation, to test the unique index
    expect { described_class.insert_all!([row]) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'takes a tool from 0' do
    expect(build(:gcode_summary_tool, tool: -1)).not_to be_valid
  end

  it 'takes a material of Filament::MATERIALS, or none' do
    expect(build(:gcode_summary_tool, material: 'PCTG')).not_to be_valid
    expect(build(:gcode_summary_tool, material: nil, material_raw: 'PCTG')).to be_valid
  end

  it 'keeps every value Not known but the tool' do
    expect(build(:gcode_summary_tool, material: nil, material_raw: nil, colour_hex: nil, grams: nil,
                                      millimetres: nil)).to be_valid
  end
end
