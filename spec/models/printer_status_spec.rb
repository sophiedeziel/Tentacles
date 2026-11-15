# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterStatus do
  let(:now) { Time.zone.parse('2026-11-15 12:00:00.123') }
  let(:attributes) do
    {
      printer_id: 1,
      state_family: PrinterStateFamily::Printing,
      state_text: 'Printing',
      file_name: 'cube.gcode',
      progress: 42.4,
      print_time_left: 600,
      hotend: PrinterStatus::Temperature.new(actual: 210.3, target: 210.0),
      bed: PrinterStatus::Temperature.new(actual: 59.8, target: 60.0),
      camera: PrinterStatus::Camera.new(enabled: true, stream_url: 'http://10.0.1.165/webcam/?action=stream'),
      last_seen_at: now,
      updated_at: now
    }
  end
  let(:status) { described_class.new(**attributes) }

  describe '.unknown' do
    subject { described_class.unknown(printer_id: 3, last_seen_at: now) }

    its(:printer_id) { is_expected.to eq 3 }
    its(:state_family) { is_expected.to eq PrinterStateFamily::Offline }
    its(:state_text) { is_expected.to eq 'Unknown' }
    its(:last_seen_at) { is_expected.to eq now }
    its(:camera) { is_expected.to have_attributes(enabled: false, stream_url: nil) }
  end

  describe 'JSON serialization' do
    it 'round-trips every attribute' do
      restored = described_class.from_json(status.to_json)

      expect(restored.serialize.except('last_seen_at', 'updated_at'))
        .to eq status.serialize.except('last_seen_at', 'updated_at')
      expect(restored.last_seen_at).to be_within(0.001).of(now)
      expect(restored.updated_at).to be_within(0.001).of(now)
    end

    it 'stores the state family by name and the times as ISO 8601' do
      json = JSON.parse(status.to_json)

      expect(json).to include('state_family' => 'PRINTING', 'updated_at' => '2026-11-15T12:00:00.123Z')
    end

    it 'round-trips missing optional attributes' do
      unknown = described_class.unknown(printer_id: 3)

      expect(described_class.from_json(unknown.to_json)).to eq unknown
    end
  end

  describe '#same_as?' do
    def changed(**changes)
      described_class.new(**attributes, **changes)
    end

    it 'is false without a previous snapshot' do
      expect(status.same_as?(nil)).to be false
    end

    it 'ignores the timestamps' do
      expect(changed(updated_at: now + 1.minute, last_seen_at: now + 1.minute).same_as?(status)).to be true
    end

    it 'ignores changes under 1°, 1 % and 1 minute' do
      jittered = changed(
        hotend: PrinterStatus::Temperature.new(actual: 210.4, target: 210.0),
        progress: 42.1,
        print_time_left: 589
      )

      expect(jittered.same_as?(status)).to be true
    end

    it 'detects a temperature change once rounded' do
      expect(changed(hotend: PrinterStatus::Temperature.new(actual: 211.0, target: 210.0)).same_as?(status)).to be false
    end

    it 'detects a progress change once rounded' do
      expect(changed(progress: 43.0).same_as?(status)).to be false
    end

    it 'detects a time left change once rounded to the minute' do
      expect(changed(print_time_left: 660).same_as?(status)).to be false
    end

    it 'detects state, file and camera changes' do
      expect(changed(state_family: PrinterStateFamily::Paused, state_text: 'Paused').same_as?(status)).to be false
      expect(changed(file_name: 'other.gcode').same_as?(status)).to be false
      expect(changed(camera: PrinterStatus::Camera.new(enabled: false)).same_as?(status)).to be false
    end
  end
end
