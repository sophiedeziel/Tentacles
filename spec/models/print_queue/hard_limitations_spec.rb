# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::HardLimitations do
  def needs(materials: [], **values)
    tools = materials.each_with_index.map { |material, tool| PrintQueue::Needs::Tool.new(tool:, material:) }
    PrintQueue::Needs.new(known: true, tools:, **values)
  end

  def limitations(needs, **specs)
    described_class.new(needs:, printer: build(:printer, **specs))
  end

  describe 'a rectangular bed' do
    let(:bed) { { build_volume_x: 180, build_volume_y: 180, build_volume_z: 180 } }

    it 'is too small when the footprint is wider or deeper' do
      reasons = limitations(needs(width: 230, depth: 210), **bed).reasons

      expect(reasons.map(&:to_h)).to eq [
        { code: :bed_too_small, message: 'Bed too small: needs 230 × 210 mm, has 180 × 180 mm' }
      ]
      expect(limitations(needs(width: 181, depth: 10), **bed)).to be_any
      expect(limitations(needs(width: 10, depth: 180.5), **bed)).to be_any
    end

    it 'fits a footprint as large as the bed' do
      expect(limitations(needs(width: 180, depth: 180), **bed)).to be_none
    end

    it 'compares the sides it knows, when the printer knows one' do
      reasons = limitations(needs(width: 230, depth: 10), build_volume_x: 180).reasons

      expect(reasons.map(&:message)).to eq ['Bed too small: needs 230 × 10 mm, has 180 × ? mm']
      expect(limitations(needs(width: 10, depth: 230), build_volume_x: 180)).to be_none
    end

    it 'shows the sizes to the hundredth of a mm' do
      reasons = limitations(needs(width: 123.09, depth: 10), build_volume_x: 120.5, build_volume_y: 120).reasons

      expect(reasons.map(&:message)).to eq ['Bed too small: needs 123.09 × 10 mm, has 120.5 × 120 mm']
    end
  end

  describe 'a round bed' do
    let(:bed) { { bed_shape: 'circular', build_diameter: 180, build_volume_z: 300 } }

    it 'is too small when a side is larger than the diameter' do
      reasons = limitations(needs(width: 200, depth: 100), **bed).reasons

      expect(reasons.map(&:to_h)).to eq [
        { code: :bed_too_small, message: 'Bed too small: needs 200 × 100 mm, has a 180 mm round bed' }
      ]
      expect(limitations(needs(width: 100, depth: 200), **bed)).to be_any
    end

    it 'is lenient: a box whose sides fit the diameter fits, even if its corners would not' do
      expect(limitations(needs(width: 170, depth: 170), **bed)).to be_none
    end

    it 'ignores the X and Y of a round bed' do
      expect(limitations(needs(width: 170, depth: 170), **bed, build_volume_x: 100, build_volume_y: 100)).to be_none
    end
  end

  it 'is too short when the print is taller than the build volume' do
    reasons = limitations(needs(height: 250), build_volume_z: 200).reasons

    expect(reasons.map(&:to_h)).to eq [{ code: :too_tall, message: 'Too tall: needs 250 mm of height, has 200 mm' }]
    expect(limitations(needs(height: 200), build_volume_z: 200)).to be_none
  end

  it 'needs as many tools as the file uses' do
    reasons = limitations(needs(tool_count: 2), extruders: 1).reasons

    expect(reasons.map(&:to_h)).to eq [{ code: :too_few_tools, message: 'Needs 2 tools, has 1' }]
    expect(limitations(needs(tool_count: 2), extruders: 2)).to be_none
  end

  describe 'materials' do
    it 'refuses a material the printer does not list' do
      reasons = limitations(needs(materials: %w[PLA PETG ASA PETG]), materials: %w[PLA ABS]).reasons

      expect(reasons.map(&:to_h)).to eq [
        { code: :material_not_printed, message: "Doesn't print PETG, ASA (prints PLA, ABS)" }
      ]
    end

    it 'compares by material key' do
      expect(limitations(needs(materials: %w[PLA]), materials: [' pla '])).to be_none
    end

    it 'holds nothing against a printer that lists no materials' do
      expect(limitations(needs(materials: %w[PETG]), materials: [])).to be_none
    end

    it 'holds nothing against a printer saved without a materials list (nil)' do
      printer = create(:printer)
      printer.update_column(:materials, nil) # rubocop:disable Rails/SkipsModelValidations

      expect(described_class.new(needs: needs(materials: %w[PETG]), printer: Printer.find(printer.id))).to be_none
    end

    it 'holds nothing against a material Not known' do
      expect(limitations(needs(materials: [nil]), materials: %w[PLA])).to be_none
    end
  end

  it 'lists every limitation, in order' do
    reasons = limitations(needs(width: 300, depth: 300, height: 300, tool_count: 2, materials: %w[PETG]),
                          build_volume_x: 180, build_volume_y: 180, build_volume_z: 180, extruders: 1,
                          materials: %w[PLA]).reasons

    expect(reasons.map(&:code)).to eq %i[bed_too_small too_tall too_few_tools material_not_printed]
  end

  describe 'a value the file does not state' do
    let(:tiny) do
      { build_volume_x: 1, build_volume_y: 1, build_volume_z: 1, extruders: 1, materials: %w[PLA] }
    end

    it 'is never a hard limitation' do
      unknown = PrintQueue::Needs.new(tools: [PrintQueue::Needs::Tool.new(tool: 0)])

      expect(limitations(unknown, **tiny)).to be_none
      expect(limitations(PrintQueue::Needs.new, **tiny, bed_shape: 'circular', build_diameter: 1)).to be_none
    end
  end

  describe 'a spec the printer does not have' do
    it 'is never a hard limitation' do
      big = needs(width: 900, depth: 900, height: 900, tool_count: 5, materials: %w[PC])

      expect(limitations(big)).to be_none
      expect(limitations(big, bed_shape: 'circular')).to be_none
    end
  end

  it 'is read-only' do
    expect { limitations(needs).save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
