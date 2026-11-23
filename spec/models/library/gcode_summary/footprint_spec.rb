# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::GcodeSummary::Footprint do
  def footprint_of(**columns)
    described_class.of(build(:gcode_summary, :ready, **columns))
  end

  it 'derives the size from the box, and keeps the height and the source' do
    footprint = footprint_of(min_x: 2, max_x: 125.09, min_y: 10, max_y: 140, max_z: 15.2, footprint_source: 'slicer')

    expect(footprint).to have_attributes(width: 123.09, depth: 130, height: 15.2, min_x: 2, max_x: 125.09,
                                         min_y: 10, max_y: 140, source: 'slicer')
  end

  it 'keeps a height Not known' do
    expect(footprint_of(max_z: nil).height).to be_nil
  end

  it 'is nil when a side is Not known' do
    %i[min_x max_x min_y max_y].each { |side| expect(footprint_of(side => nil)).to be_nil }
  end

  it 'is read-only' do
    expect { footprint_of.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
