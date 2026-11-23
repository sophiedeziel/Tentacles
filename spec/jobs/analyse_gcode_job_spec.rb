# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyseGcodeJob, type: :job do
  let(:item) { create(:file_record) }

  describe '#perform' do
    it 'reads the file into its summary' do
      described_class.perform_now(item.id)

      expect(item.reload.gcode_summary).to have_attributes(status: 'ready', slicer: 'Cura', print_seconds: 4271)
    end

    it 'does nothing when the file was deleted since' do
      expect { described_class.perform_now(item.id + 1) }.not_to change(Library::GcodeSummary, :count)
    end

    it 'does nothing for a file that is not G-code' do
      item.file.attach(io: StringIO.new('solid cube'), filename: 'cube.stl')

      expect { described_class.perform_now(item.id) }.not_to change(Library::GcodeSummary, :count)
    end

    it 'retries a storage error, and fails the row after the third attempt' do
      create(:gcode_summary, item:)
      allow(Gcode::Summary).to receive(:read_file).and_raise(ActiveStorage::FileNotFoundError)
      allow(Rails.logger).to receive(:warn)

      perform_enqueued_jobs { described_class.perform_later(item.id) }

      expect(Gcode::Summary).to have_received(:read_file).exactly(3).times
      expect(item.reload.gcode_summary).to have_attributes(status: 'failed',
                                                           error: 'Could not read the file from storage')
    end

    it 'fails the row on an unexpected error, and raises it' do
      allow(Gcode::Summary).to receive(:read_file).and_raise(ArgumentError, 'a bug')

      expect { described_class.perform_now(item.id) }.to raise_error(ArgumentError, 'a bug')
      expect(item.reload.gcode_summary).to have_attributes(status: 'failed', error: 'Could not analyse this file')
    end
  end
end
