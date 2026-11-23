# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gcode::Summary do
  def read_fixture(name)
    Rails.root.join('spec/fixture_files/gcode', name).open { |io| described_class.read(io) }
  end

  def read_gcode(text)
    described_class.read(StringIO.new(text))
  end

  def box(summary)
    summary.attributes.slice('min_x', 'max_x', 'min_y', 'max_y', 'max_z').transform_values { |value| value&.to_f }
  end

  def tools(summary)
    summary.tools.map do |tool|
      tool.attributes.transform_values { |value| value.is_a?(BigDecimal) ? value.to_f : value }
    end
  end

  it 'is read-only' do
    expect { described_class.new.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end

  describe '.read_file' do
    it 'reads an Active Storage attachment' do
      item = create(:file_record)

      expect(described_class.read_file(item.file)).to have_attributes(slicer: 'Cura', print_seconds: 4271)
    end
  end

  describe 'a PrusaSlicer file' do
    subject(:summary) { read_fixture('prusaslicer_single.gcode') }

    it 'reads the slicer, its version and the time from the footer' do
      expect(summary).to have_attributes(slicer: 'PrusaSlicer', slicer_version: '2.9.6', print_seconds: 1828)
    end

    it 'reads the filament of its one tool' do
      expect(tools(summary)).to eq [{ 'tool' => 0, 'material' => 'PLA', 'material_raw' => 'PLA',
                                      'colour_hex' => '#DDDDDD', 'grams' => 2.63, 'millimetres' => 882.3 }]
    end

    it 'computes the footprint from the extruding moves, prime lines included' do
      expect(box(summary)).to eq('min_x' => 2.0, 'max_x' => 125.09, 'min_y' => 10.0, 'max_y' => 140.0,
                                 'max_z' => 0.41)
      expect(summary.footprint_source).to eq 'moves'
    end

    it 'has one tool and no change' do
      expect(summary).to have_attributes(tool_count: 1, tool_changes: 0, filament_changes: [])
    end
  end

  describe 'a multi-tool PrusaSlicer file' do
    subject(:summary) { read_fixture('prusaslicer_multi_tool.gcode') }

    it 'maps the lists to the tools by position, leaving out the tools that are never used' do
      expect(tools(summary)).to eq [
        { 'tool' => 0, 'material' => 'PLA', 'material_raw' => 'PLA', 'colour_hex' => '#DDDDDD', 'grams' => 2.63,
          'millimetres' => 882.3 },
        { 'tool' => 1, 'material' => 'PETG', 'material_raw' => 'PETG', 'colour_hex' => '#FF8000', 'grams' => 0.36,
          'millimetres' => 120.5 }
      ]
    end

    it 'counts the tools that extrude and the changes after the first selection' do
      expect(summary).to have_attributes(tool_count: 2, tool_changes: 2)
    end
  end

  describe 'a PrusaSlicer file with colour changes' do
    subject(:summary) { read_fixture('prusaslicer_m600.gcode') }

    it 'records each M600 with its line, Z and layer, a ;COLOR_CHANGE and its M600 counting once' do
      expect(summary.filament_changes).to eq [
        { 'line' => 102, 'z' => 0.41, 'layer' => 2 },
        { 'line' => 124, 'z' => 0.41, 'layer' => 2 }
      ]
    end
  end

  describe 'a PrusaSlicer file whose material is not a known one' do
    subject(:summary) { read_fixture('prusaslicer_unknown_material.gcode') }

    it 'keeps the material as written, with no colour and no grams' do
      expect(tools(summary)).to eq [{ 'tool' => 0, 'material' => nil, 'material_raw' => 'PCTG', 'colour_hex' => nil,
                                      'grams' => nil, 'millimetres' => 882.3 }]
    end
  end

  describe 'a Cura file' do
    subject(:summary) { read_fixture('cura_single.gcode') }

    it 'reads the slicer, the time and the length from the header' do
      expect(summary).to have_attributes(slicer: 'Cura', slicer_version: '4.11.0', print_seconds: 4271)
      expect(tools(summary)).to eq [{ 'tool' => 0, 'material' => nil, 'material_raw' => nil, 'colour_hex' => nil,
                                      'grams' => nil, 'millimetres' => 797.7 }]
    end

    it "takes the slicer's box over the moves" do
      expect(box(summary)).to eq('min_x' => 119.5, 'max_x' => 180.5, 'min_y' => 39.5, 'max_y' => 260.5,
                                 'max_z' => 0.36)
      expect(summary.footprint_source).to eq 'slicer'
    end

    it 'reads several tools from the length list, in metres' do
      summary = read_gcode(<<~GCODE)
        ;TIME:60.4
        ;Filament used: 1.5m, 0.25m
        ;Generated with Cura_SteamEngine 5.7.1
        T0
        G1 X0 Y0 E1
        T1
        G1 X1 Y1 E2
      GCODE

      expect(summary.print_seconds).to eq 60
      expect(summary.tools.map(&:millimetres)).to eq [1500, 250]
    end
  end

  describe 'a file from another slicer' do
    subject(:summary) { read_fixture('unknown_slicer.gcode') }

    it 'knows only what the moves tell' do
      expect(summary).to have_attributes(slicer: nil, slicer_version: nil, print_seconds: nil, tool_count: 1,
                                         tool_changes: 0, footprint_source: 'moves')
      expect(box(summary)).to include('min_x' => 2.0, 'max_x' => 125.09)
      expect(tools(summary)).to eq [{ 'tool' => 0, 'material' => nil, 'material_raw' => nil, 'colour_hex' => nil,
                                      'grams' => nil, 'millimetres' => nil }]
    end
  end

  describe 'a file cut before its footer' do
    subject(:summary) { read_fixture('truncated.gcode') }

    it 'knows what it read' do
      expect(summary).to have_attributes(slicer: 'PrusaSlicer', print_seconds: nil, tool_count: 1,
                                         footprint_source: 'moves')
      expect(tools(summary).first).to include('material' => nil, 'grams' => nil, 'millimetres' => nil)
    end
  end

  describe 'a file with relative extrusion and positions' do
    subject(:summary) { read_fixture('relative_extrusion.gcode') }

    it 'leaves out travels, retractions and extrusion in place, and follows G91 and G92' do
      expect(box(summary)).to eq('min_x' => 10.0, 'max_x' => 80.0, 'min_y' => 10.0, 'max_y' => 60.0,
                                 'max_z' => 0.4)
    end
  end

  describe 'a binary file' do
    it 'raises Unreadable' do
      expect { read_fixture('binary.bgcode') }
        .to raise_error(described_class::Unreadable, 'Not a G-code text file (binary G-code is not supported)')
    end
  end

  describe 'an empty file' do
    it 'knows nothing' do
      expect(read_gcode('')).to have_attributes(slicer: nil, tool_count: nil, tool_changes: nil, tools: [],
                                                footprint_source: nil, filament_changes: [])
    end
  end

  describe 'the time' do
    def time(value)
      read_gcode(<<~GCODE).print_seconds
        ; generated by PrusaSlicer 2.9.6 on 2026-09-07 at 03:58:17 UTC
        G1 X0
        ; estimated printing time (normal mode) = #{value}
      GCODE
    end

    it 'reads days, hours, minutes and seconds' do
      expect(time('1d 2h 3m 4s')).to eq 93_784
      expect(time('45m 10s')).to eq 2710
      expect(time('30s')).to eq 30
    end

    it 'is Not known when malformed' do
      expect(time('soon')).to be_nil
      expect(time('')).to be_nil
    end
  end

  describe 'the material' do
    it 'is normalised to a key of Filament::MATERIALS' do
      summary = read_gcode(<<~GCODE)
        ; generated by PrusaSlicer 2.9.6 on 2026-09-07 at 03:58:17 UTC
        G1 X0 Y0 E1
        ; filament_type =  pla ;PCTG
        ; filament used [mm] = 10.00, 5.00
        ; filament_colour = "#ff8000";not a colour
      GCODE

      expect(tools(summary)).to eq [
        { 'tool' => 0, 'material' => 'PLA', 'material_raw' => 'pla', 'colour_hex' => '#ff8000', 'grams' => nil,
          'millimetres' => 10.0 },
        { 'tool' => 1, 'material' => nil, 'material_raw' => 'PCTG', 'colour_hex' => nil, 'grams' => nil,
          'millimetres' => 5.0 }
      ]
    end
  end

  describe 'the footprint' do
    it 'leaves out travel moves and retractions in absolute extrusion, and honours G92 E0' do
      summary = read_gcode(<<~GCODE)
        M82
        G92 E0
        G1 X10 Y10 Z0.2 F3000
        G1 X20 Y10 E1
        G1 E0.2
        G1 X90 Y90
        G92 E0
        G1 X100 Y100 E0
        G1 X20 Y30 E0.5
      GCODE

      expect(box(summary)).to eq('min_x' => 10.0, 'max_x' => 100.0, 'min_y' => 10.0, 'max_y' => 100.0,
                                 'max_z' => 0.2)
    end

    it 'keeps the absolute E position through relative moves' do
      summary = read_gcode(<<~GCODE)
        M82
        G1 X10 Y10 Z0.2
        G1 X20 E5
        G91
        G1 E10
        G90
        G1 X200 Y100 E12
      GCODE

      expect(box(summary)).to include('max_x' => 20.0, 'max_y' => 10.0)
    end

    it 'is Not known when a side is beyond what the columns hold' do
      summary = read_gcode("G1 X10 Y10 Z0.2\nG1 X100000 Y20 E1\n")

      expect(box(summary).values).to all(be_nil)
      expect(summary.footprint_source).to be_nil
    end

    it 'counts arcs by their ends' do
      summary = read_gcode("G1 X10 Y10 Z0.3\nG2 X30 Y10 I10 J0 E1\n")

      expect(box(summary)).to eq('min_x' => 10.0, 'max_x' => 30.0, 'min_y' => 10.0, 'max_y' => 10.0, 'max_z' => 0.3)
    end

    it 'leaves out the start of a move whose position is unknown after homing' do
      summary = read_gcode("G1 X150 Y150\nG28\nG1 X10 Y20 E1\nG1 X30 Y40 E2\n")

      expect(box(summary)).to include('min_x' => 10.0, 'max_x' => 30.0, 'min_y' => 20.0, 'max_y' => 40.0)
    end

    it 'is Not known when nothing extrudes' do
      expect(box(read_gcode("G1 X10 Y10\nG1 X20 Y20\n")).values).to all(be_nil)
    end
  end

  describe 'the tools' do
    it 'count 1 for a file that extrudes without selecting a tool' do
      expect(read_gcode("G1 X0 Y0 E1\n")).to have_attributes(tool_count: 1, tool_changes: 0)
    end

    it 'count the tool selected after a prime line as the one that drew it' do
      expect(read_gcode("G1 X0 Y0 E1\nT1\nG1 X5 E2\n").tools.map(&:tool)).to eq [1]
    end

    it 'count a change only when the tool differs, the first selection excluded' do
      summary = read_gcode("T0\nG1 X0 Y0 E1\nT0\nT1\nG1 X5 E2\nT1\nT0\nG1 X9 E3\n")

      expect(summary).to have_attributes(tool_count: 2, tool_changes: 2)
    end

    it 'are Not known when nothing extrudes' do
      expect(read_gcode("T0\nG1 X10 Y10\n")).to have_attributes(tool_count: nil, tool_changes: nil, tools: [])
    end
  end

  describe 'the filament changes' do
    it 'record a bare M600 with its Z, and no layer for a file from another slicer' do
      summary = read_gcode("G1 X0 Y0 Z1.2 E1\nM600\n")

      expect(summary.filament_changes).to eq [{ 'line' => 2, 'z' => 1.2, 'layer' => nil }]
    end

    it 'read the layer from Cura, counting from 1' do
      summary = read_gcode(<<~GCODE)
        ;Generated with Cura_SteamEngine 4.11.0
        G1 X0 Y0 Z0.2 E1
        ;LAYER:0
        ;LAYER:1
        G1 Z0.4
        M600
      GCODE

      expect(summary.filament_changes).to eq [{ 'line' => 6, 'z' => 0.4, 'layer' => 2 }]
    end
  end

  describe 'values beyond what the columns hold' do
    it 'are Not known, and long texts are cut' do
      summary = read_gcode(<<~GCODE)
        ; generated by PrusaSlicer 2.9.6 on 2026-09-07 at 03:58:17 UTC
        T9999
        G1 X0 Y0 E1
        ; filament used [mm] = 1e12
        ; filament used [g] = 1e7
        ; filament_type = #{'X' * 300}
        ; estimated printing time (normal mode) = 99999d 0s
      GCODE

      expect(summary).to have_attributes(print_seconds: nil, tool_count: 1)
      expect(summary.tools.first).to have_attributes(tool: 0, millimetres: nil, grams: nil)
      expect(summary.tools.first.material_raw.length).to eq 255
    end
  end

  describe 'a line that does not parse' do
    it 'is skipped without changing anything else' do
      good = "G1 X10 Y10 Z0.2\nG1 X20 Y20 E1\nT1\nG1 X30 E2\n"
      bad = "G1 X10 Y10 Z0.2\nG1 Xbad Y500 E9\nG1 X20 Y20 E1\nT1\nG1 X30 E2\nT\xFF\n"

      expect(read_gcode(bad).attributes.except('tools')).to eq read_gcode(good).attributes.except('tools')
    end
  end
end
