# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::GcodeSummaryRefresh do
  let(:item) { create(:file_record) }

  def attach(name, filename: 'part.gcode')
    item.file.attach(io: Rails.root.join('spec/fixture_files/gcode', name).open, filename:)
  end

  it 'refuses a file that is not G-code' do
    item.file.attach(io: StringIO.new('solid cube'), filename: 'cube.stl')
    refresh = described_class.new(item:)

    expect(refresh.save).to be false
    expect(refresh.errors[:item]).to eq ['is not a G-code file']
  end

  it 'creates the row, and fills it with the values and the tools read' do
    attach('prusaslicer_multi_tool.gcode')

    described_class.new(item:).save!

    expect(item.reload.gcode_summary).to have_attributes(
      status: 'ready', analysis_version: Gcode::Summary::VERSION, analysed_at: be_within(1.second).of(Time.current),
      error: nil, slicer: 'PrusaSlicer', slicer_version: '2.9.6', print_seconds: 1828, min_x: 2, max_x: 140,
      min_y: 10, max_y: 140, max_z: 0.41, footprint_source: 'moves', tool_count: 2, tool_changes: 2,
      filament_changes: []
    )
    expect(item.gcode_summary.tools.map { |tool| [tool.tool, tool.material, tool.colour_hex, tool.grams] })
      .to eq [[0, 'PLA', '#DDDDDD', 2.63], [1, 'PETG', '#FF8000', 0.36]]
  end

  it 'replaces the values and the tools of a pending row' do
    attach('prusaslicer_multi_tool.gcode')
    described_class.new(item:).save!
    item.gcode_summary.update!(status: 'pending')
    attach('cura_single.gcode')

    described_class.new(item: item.reload).save!

    expect(item.reload.gcode_summary).to have_attributes(status: 'ready', slicer: 'Cura', footprint_source: 'slicer',
                                                         tool_changes: 0)
    expect(item.gcode_summary.tools.map { |tool| [tool.tool, tool.material, tool.millimetres] })
      .to eq [[0, nil, 797.7]]
  end

  it 'skips a current row' do
    summary = create(:gcode_summary, :ready, item:, slicer: 'Kept')
    allow(Gcode::Summary).to receive(:read_file)

    described_class.new(item:).save!

    expect(Gcode::Summary).not_to have_received(:read_file)
    expect(summary.reload.slicer).to eq 'Kept'
  end

  it 'reads again a row read by an older version' do
    create(:gcode_summary, :ready, item:, slicer: 'Old', analysis_version: Gcode::Summary::VERSION - 1)

    described_class.new(item:).save!

    expect(item.reload.gcode_summary).to have_attributes(slicer: 'Cura', analysis_version: Gcode::Summary::VERSION)
  end

  it 'fails the row of a file that is not G-code text, clearing its values' do
    create(:gcode_summary, :ready, item:, analysis_version: 0).tap do |summary|
      create(:gcode_summary_tool, gcode_summary: summary)
    end
    attach('binary.bgcode', filename: 'binary.gcode')

    expect(described_class.new(item: item.reload).save!).to be true
    expect(item.reload.gcode_summary).to have_attributes(
      status: 'failed', error: 'Not a G-code text file (binary G-code is not supported)', slicer: nil,
      print_seconds: nil, tool_count: nil, analysis_version: Gcode::Summary::VERSION
    )
    expect(item.gcode_summary.tools).to be_empty
  end

  it 'throws the values away when the file changed while it was read' do
    allow(Gcode::Summary).to receive(:read_file).and_wrap_original do |original, file|
      original.call(file).tap { Library::Item.find(item.id).file.attach(io: StringIO.new('G1 X1'), filename: 'new.gcode') }
    end

    described_class.new(item:).save!

    expect(item.reload.gcode_summary).to have_attributes(status: 'pending', slicer: nil)
  end

  describe 'the global queue' do
    let(:dispatch_request) { instance_spy(PrintQueue::DispatchRequest, save: true) }

    before do
      attach('prusaslicer_multi_tool.gcode')
      allow(PrintQueue).to receive(:enabled?).and_return(true)
      allow(PrintQueue::DispatchRequest).to receive(:new).and_return(dispatch_request)
    end

    it 'asks for a dispatch pass once the summary of a queued file is written: its entry may now be runnable' do
      create(:print_job, item:)
      allow(dispatch_request).to receive(:save) { expect(item.gcode_summary.reload.status).to eq 'ready' }

      described_class.new(item:).save!

      expect(dispatch_request).to have_received(:save).once
    end

    it 'asks for one when the summary of a queued file failed: its entry is runnable' do
      create(:print_job, item:)
      allow(Gcode::Summary).to receive(:read_file).and_raise(Gcode::Summary::Unreadable, 'Not a G-code text file')

      described_class.new(item:).save!

      expect(dispatch_request).to have_received(:save).once
    end

    it 'asks for nothing for a file that is not in the queue' do
      done = create(:print_job, item:, copies: 1)
      create(:printer_job, :copy, print_job: done, status: 'completed')

      described_class.new(item:).save!

      expect(PrintQueue::DispatchRequest).not_to have_received(:new)
    end

    it 'asks for nothing when the row was current already' do
      create(:print_job, item:)
      create(:gcode_summary, :ready, item:)

      described_class.new(item:).save!

      expect(PrintQueue::DispatchRequest).not_to have_received(:new)
    end

    it 'asks for nothing when the values read are thrown away' do
      create(:print_job, item:)
      allow(Gcode::Summary).to receive(:read_file).and_wrap_original do |original, file|
        original.call(file).tap { Library::Item.find(item.id).file.attach(io: StringIO.new('G1 X1'), filename: 'n.gcode') }
      end

      described_class.new(item:).save!

      expect(PrintQueue::DispatchRequest).not_to have_received(:new)
    end

    it 'asks for nothing while the global queue is off' do
      allow(PrintQueue).to receive(:enabled?).and_return(false)
      create(:print_job, item:)

      described_class.new(item:).save!

      expect(PrintQueue::DispatchRequest).not_to have_received(:new)
    end
  end

  it 'raises a storage error, for the job to retry' do
    allow(Gcode::Summary).to receive(:read_file).and_raise(ActiveStorage::FileNotFoundError)

    expect { described_class.new(item:).save! }.to raise_error(ActiveStorage::FileNotFoundError)
  end
end
