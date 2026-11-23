# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::GcodeSummary do
  subject(:summary) { create(:gcode_summary) }

  it 'starts pending, read by no version, with no filament change' do
    expect(summary).to have_attributes(status: 'pending', analysis_version: 0, filament_changes: [])
  end

  it 'is one per file' do
    expect(build(:gcode_summary, item: summary.item)).not_to be_valid
    row = { file_record_id: summary.file_record_id, created_at: Time.current, updated_at: Time.current }
    # rubocop:disable-next Rails/SkipsModelValidations -- past the validation, to test the unique index
    expect { described_class.insert_all!([row]) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'refuses an unknown status or footprint source' do
    expect(build(:gcode_summary, status: 'done')).not_to be_valid
    expect(build(:gcode_summary, footprint_source: 'guess')).not_to be_valid
    expect(build(:gcode_summary, footprint_source: nil)).to be_valid
  end

  it 'lists its tools by number' do
    create(:gcode_summary_tool, gcode_summary: summary, tool: 1)
    create(:gcode_summary_tool, gcode_summary: summary, tool: 0)

    expect(summary.reload.tools.map(&:tool)).to eq [0, 1]
  end

  it 'is deleted with its file, and its tools with it' do
    create(:gcode_summary_tool, gcode_summary: summary)

    expect { summary.item.destroy! }.to change(described_class, :count).by(-1)
                                    .and change(Library::GcodeSummary::Tool, :count).by(-1)
  end

  it 'is deleted with its file by the database too' do
    create(:gcode_summary_tool, gcode_summary: summary)

    expect { Library::Item.where(id: summary.file_record_id).delete_all }
      .to change(described_class, :count).by(-1).and change(Library::GcodeSummary::Tool, :count).by(-1)
  end

  describe '#current?' do
    it 'is true for a ready row read by the current version' do
      expect(build(:gcode_summary, :ready)).to be_current
    end

    it 'is false for a pending or failed row, or one read by an older version' do
      expect(build(:gcode_summary)).not_to be_current
      expect(build(:gcode_summary, :ready, status: 'failed')).not_to be_current
      expect(build(:gcode_summary, :ready, analysis_version: Gcode::Summary::VERSION - 1)).not_to be_current
    end
  end

  describe '#filament_grams and #filament_millimetres' do
    it 'add up the tools' do
      create(:gcode_summary_tool, gcode_summary: summary, grams: 2.5, millimetres: 800)
      create(:gcode_summary_tool, gcode_summary: summary, grams: 1.25, millimetres: 400.5)

      expect(summary.reload).to have_attributes(filament_grams: 3.75, filament_millimetres: 1200.5)
    end

    it 'are Not known when any tool is' do
      create(:gcode_summary_tool, gcode_summary: summary, grams: 2.5, millimetres: 800)
      create(:gcode_summary_tool, gcode_summary: summary, grams: nil, millimetres: 400)

      expect(summary.reload).to have_attributes(filament_grams: nil, filament_millimetres: 1200)
    end

    it 'are Not known with no tool' do
      expect(summary).to have_attributes(filament_grams: nil, filament_millimetres: nil)
    end
  end

  describe '#footprint' do
    it 'is the Footprint of the box' do
      summary = build(:gcode_summary, :ready, min_x: 2, max_x: 125.09, min_y: 10, max_y: 140, max_z: 15.2)

      expect(summary.footprint).to have_attributes(min_x: 2, max_x: 125.09, height: 15.2, source: 'moves')
    end

    it 'is Not known without a box' do
      expect(build(:gcode_summary, :ready, max_y: nil).footprint).to be_nil
    end
  end
end
