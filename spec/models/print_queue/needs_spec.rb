# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Needs do
  let(:entry) { create(:print_job, colour: 'Black') }

  def summary(*traits, **attributes)
    create(:gcode_summary, *traits, item: entry.item, **attributes)
  end

  describe '.of' do
    it 'reads a ready summary: tools, footprint, height, tool count, M600 list, and the colour of the entry' do
      changes = [{ 'line' => 1234, 'z' => 5.4, 'layer' => 27 }]
      summary(:ready, :with_tools, materials: ['PLA', nil], filament_changes: changes)

      needs = described_class.of(entry)

      expect(needs).to be_known
      expect(needs).to be_runnable
      expect(needs).to have_attributes(colour: 'Black', width: 123.09, depth: 130, height: 15, tool_count: 2,
                                       filament_changes: changes)
      expect(needs.tools.map { |tool| [tool.tool, tool.material] }).to eq [[0, 'PLA'], [1, nil]]
      expect(needs.footprint).to have_attributes(min_x: 2, max_x: 125.09, min_y: 10, max_y: 140, source: 'moves')
    end

    it 'is Any colour when the entry asks for none' do
      entry.update!(colour: nil)
      summary(:ready)

      expect(described_class.of(entry).colour).to be_nil
    end

    it 'keeps the height when the box is Not known' do
      summary(:ready, min_x: nil)

      expect(described_class.of(entry)).to have_attributes(width: nil, depth: nil, height: 15, footprint: nil)
    end

    it 'follows a recomputed summary (no snapshot)' do
      gcode_summary = summary(:ready, :with_tools, materials: ['PLA'])
      gcode_summary.tools.first.update!(material: 'PETG')

      expect(described_class.of(entry.reload).tools.map(&:material)).to eq ['PETG']
    end

    context 'when the entry asks for a material' do
      before { entry.update!(material: 'PETG') }

      it "replaces the material of a file of one tool, keeping the summary's other values" do
        summary(:ready, :with_tools, materials: ['PLA'])

        needs = described_class.of(entry)

        expect(needs.tools.map { |tool| [tool.tool, tool.material] }).to eq [[0, 'PETG']]
        expect(needs).to have_attributes(known: true, tool_count: 1, width: 123.09)
      end

      it 'asks it of tool 0 when the summary knows no tool' do
        summary(:ready)

        expect(described_class.of(entry).tools.map { |tool| [tool.tool, tool.material] }).to eq [[0, 'PETG']]
      end

      it "keeps the summary's materials for a file of several tools (one per tool is phase 9)" do
        summary(:ready, :with_tools, materials: %w[PLA PLA])

        expect(described_class.of(entry).tools.map(&:material)).to eq %w[PLA PLA]
      end

      it 'is known even when the summary failed, every other value Not known' do
        summary(:failed)

        needs = described_class.of(entry)

        expect(needs.tools.map(&:material)).to eq ['PETG']
        expect(needs).to have_attributes(known: false, runnable: true, width: nil, tool_count: nil)
      end

      it 'is asked while the summary is pending' do
        summary(status: 'pending')

        needs = described_class.of(entry)

        expect(needs).not_to be_runnable
        expect(needs.tools.map(&:material)).to eq ['PETG']
      end
    end

    it 'is not runnable while the summary is pending' do
      summary(status: 'pending')

      needs = described_class.of(entry)

      expect(needs).not_to be_runnable
      expect(needs).not_to be_known
    end

    it 'is not runnable for a G-code file without a summary yet' do
      expect(described_class.of(entry)).not_to be_runnable
    end

    it 'is runnable with every value Not known when the summary failed' do
      summary(:failed)

      needs = described_class.of(entry)

      expect(needs).to be_runnable
      expect(needs).not_to be_known
      expect(needs).to have_attributes(tools: [], width: nil, depth: nil, height: nil, tool_count: nil,
                                       filament_changes: [], colour: 'Black')
    end

    it 'is runnable with every value Not known for a file that is not G-code' do
      entry.item.file.attach(io: Rails.root.join('spec/fixture_files/gcode/binary.bgcode').open,
                             filename: 'part.bgcode')

      needs = described_class.of(entry)

      expect(needs).to be_runnable
      expect(needs).not_to be_known
      expect(needs).to have_attributes(tools: [], width: nil, tool_count: nil)
    end
  end

  it 'is what an entry needs' do
    summary(:ready)

    expect(entry.needs).to be_known
  end

  it 'is read-only' do
    expect { described_class.new.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
    expect { described_class::Tool.new(tool: 0).save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
