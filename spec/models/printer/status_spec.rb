# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Status do
  let(:now) { Time.zone.parse('2026-11-15 12:00:00.123') }
  let(:attributes) do
    {
      printer_id: 1,
      state_family: Printer::StateFamily::Printing,
      state_text: 'Printing',
      file_name: 'cube.gcode',
      progress: 42.4,
      print_time_left: 600,
      hotend: Printer::Status::Temperature.new(actual: 210.3, target: 210.0),
      bed: Printer::Status::Temperature.new(actual: 59.8, target: 60.0),
      camera: Printer::Status::Camera.new(enabled: true, stream_url: 'http://10.0.1.165/webcam/?action=stream'),
      last_seen_at: now,
      updated_at: now
    }
  end
  let(:status) { described_class.new(**attributes) }

  describe '.unknown' do
    subject { described_class.unknown(printer_id: 3, last_seen_at: now) }

    its(:printer_id) { is_expected.to eq 3 }
    its(:state_family) { is_expected.to eq Printer::StateFamily::Offline }
    its(:state_text) { is_expected.to eq 'Unknown' }
    its(:last_seen_at) { is_expected.to eq now }
    its(:camera) { is_expected.to have_attributes(enabled: false, stream_url: nil) }
  end

  describe '#server_reachable?' do
    it 'is true when the server answered, even with the printer disconnected' do
      offline = described_class.new(**attributes, state_family: Printer::StateFamily::Offline, state_text: 'Offline')

      expect([status, offline]).to all(be_server_reachable)
    end

    it 'is false when the monitor could not reach the server' do
      unreachable = described_class.new(**attributes, state_family: Printer::StateFamily::Offline,
                                                      state_text: described_class::UNREACHABLE_STATE_TEXT)

      expect(unreachable).not_to be_server_reachable
    end

    it 'is false for the placeholder of a printer the monitor has not reported on' do
      expect(described_class.unknown(printer_id: 3, last_seen_at: now)).not_to be_server_reachable
    end

    it 'is true for a server that answered without a state' do
      unknown_state = described_class.new(**attributes, state_family: Printer::StateFamily::Offline,
                                                        state_text: described_class::UNKNOWN_STATE_TEXT)

      expect(unknown_state).to be_server_reachable
    end
  end

  describe 'JSON serialization' do
    it 'round-trips every attribute' do
      restored = described_class.new.from_json(status.to_json)

      expect(restored.as_json.except('last_seen_at', 'updated_at'))
        .to eq status.as_json.except('last_seen_at', 'updated_at')
      expect(restored.last_seen_at).to be_within(0.001).of(now)
      expect(restored.updated_at).to be_within(0.001).of(now)
    end

    it 'stores the state family by name and the times as ISO 8601' do
      json = JSON.parse(status.to_json)

      expect(json).to include('state_family' => 'PRINTING', 'updated_at' => '2026-11-15T12:00:00.123Z')
    end

    it 'round-trips missing optional attributes' do
      unknown = described_class.unknown(printer_id: 3)

      expect(described_class.new.from_json(unknown.to_json)).to eq unknown
    end

    it 'stores the temperature unit by name' do
      expect(JSON.parse(status.to_json)['hotend']).to eq('actual' => 210.3, 'target' => 210.0, 'unit' => 'CELSIUS')
    end

    it 'reads the times back as TimeWithZone' do
      restored = described_class.new.from_json(status.to_json)

      expect(restored.updated_at).to be_a(ActiveSupport::TimeWithZone)
    end

    it 'ignores the keys that are not attributes' do
      json = { printer_id: 3, state_family: 'OFFLINE', state_text: 'Offline', removed_prop: 1 }

      expect(described_class.new.from_json(json.to_json))
        .to eq described_class.new(printer_id: 3, state_family: Printer::StateFamily::Offline, state_text: 'Offline')
    end

    it 'reads temperatures written before the unit was stored as CELSIUS' do
      json = { printer_id: 3, state_family: 'OFFLINE', state_text: 'Offline', bed: { actual: 21.0, target: 0.0 } }

      expect(described_class.new.from_json(json.to_json).bed&.unit).to eq(TemperatureUnit::Celsius)
    end
  end

  describe '#changed?' do
    # Whether the status changed since it was saved, once the changes are assigned
    def changed?(**changes)
      status.changes_applied
      status.assign_attributes(changes)
      status.changed?
    end

    it 'is true for a new snapshot' do
      expect(status).to be_changed
    end

    it 'is false once saved, until the state changes' do
      expect(changed?).to be false
    end

    it 'ignores the timestamps' do
      expect(changed?(updated_at: now + 1.minute, last_seen_at: now + 1.minute)).to be false
    end

    it 'ignores changes under 1°, 1 % and 1 minute' do
      jittered = changed?(
        hotend: Printer::Status::Temperature.new(actual: 210.4, target: 210.0),
        progress: 42.1,
        print_time_left: 589
      )

      expect(jittered).to be false
    end

    it 'detects a temperature change once rounded' do
      expect(changed?(hotend: Printer::Status::Temperature.new(actual: 211.0, target: 210.0))).to be true
    end

    it 'detects a progress change once rounded' do
      expect(changed?(progress: 43.0)).to be true
    end

    it 'detects a time left change once rounded to the minute' do
      expect(changed?(print_time_left: 660)).to be true
    end

    it 'detects state, file and camera changes' do
      expect(changed?(state_family: Printer::StateFamily::Paused, state_text: 'Paused')).to be true
      expect(changed?(file_name: 'other.gcode')).to be true
      expect(changed?(camera: Printer::Status::Camera.new(enabled: false))).to be true
    end

    it 'detects a camera changed in place' do
      status.changes_applied
      status.camera&.enabled = false

      expect(status).to be_changed
    end
  end

  describe '#reload' do
    include ActiveSupport::Testing::TimeHelpers

    let(:printer) { build_stubbed(:printer) }
    let(:status) { described_class.new(**attributes, printer:) }
    let(:read) do
      { state_family: Printer::StateFamily::Paused, state_text: 'Paused', error_text: nil, file_name: 'gear.gcode',
        progress: 10.0, print_time_left: 1200, hotend: Printer::Status::Temperature.new(actual: 200.0, target: 0.0),
        bed: nil }
    end
    # A real reader (the sig checks the type), whose read is stubbed
    let(:reader) do
      Printer::Monitor::OctoprintReader.new(printer:).tap do |reader|
        allow(reader).to receive(:status_attributes).and_return(read)
      end
    end

    it "replaces the state, job and temperatures with the printer's, stamped now, and returns the snapshot" do
      freeze_time do
        expect(status.reload(reader:)).to be(status).and have_attributes(**read, last_seen_at: Time.current,
                                                                                 updated_at: Time.current)
      end
    end

    it 'keeps the camera, which the reader does not read' do
      expect { status.reload(reader:) }.not_to(change(status, :camera))
    end

    it 'reads through a new reader for the printer by default' do
      allow(Printer::Monitor::Reader).to receive(:for).with(printer).and_return(reader)

      status.reload

      expect(reader).to have_received(:status_attributes)
    end

    it 'raises when the printer cannot be read, leaving the snapshot as it was' do
      allow(reader).to receive(:status_attributes).and_raise(Printer::Backend::Unreachable, 'timeout')

      expect { status.reload(reader:) }.to raise_error(Printer::Backend::Unreachable)
      expect(status).to have_attributes(attributes.except(:printer_id))
    end

    it 'does not save it' do
      allow(status).to receive(:save!)

      status.reload(reader:)

      expect(status).not_to have_received(:save!)
    end
  end

  describe 'persistence' do
    let(:redis) { MockRedis.new }
    let(:printer) { create(:printer) }
    let(:other_printer) { create(:printer, name: 'Other') }
    let(:operational) do
      described_class.new(printer:, state_family: Printer::StateFamily::Operational, state_text: 'Operational')
    end

    before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

    describe '#save!' do
      it 'stores the snapshot as JSON under printer_status:<id>' do
        operational.save!

        expect(JSON.parse(redis.get("printer_status:#{printer.id}"))).to include('state_family' => 'OPERATIONAL')
      end

      it 'pushes printerStatusChanged with the printer' do
        allow(TentaclesSchema.subscriptions).to receive(:trigger)

        operational.save!

        expect(TentaclesSchema.subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer)
      end

      it 'loads the printer from printer_id when it was not given' do
        allow(TentaclesSchema.subscriptions).to receive(:trigger)

        described_class.unknown(printer_id: printer.id).save!

        expect(TentaclesSchema.subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer)
      end

      it 'round-trips a time left that does not fit in 32 bits' do
        operational.print_time_left = 2**40
        operational.save!

        expect(described_class.find_by(printer_id: printer.id)&.print_time_left).to eq 2**40
      end

      it 'neither stores nor pushes an incomplete snapshot' do
        allow(TentaclesSchema.subscriptions).to receive(:trigger)

        expect { described_class.new(printer:).save! }.to raise_error(ActiveModel::ValidationError)
        expect(redis.keys).to be_empty
        expect(TentaclesSchema.subscriptions).not_to have_received(:trigger)
      end
    end

    describe '.where' do
      before do
        operational.save!
        described_class.unknown(printer_id: other_printer.id).save!
      end

      it 'reads every snapshot with a single MGET, leaving out the printers without one' do
        expect(redis).to receive(:mget).once.and_call_original
        expect(redis).not_to receive(:get)

        expect(described_class.where(printer_id: [printer.id, other_printer.id, 0]))
          .to eq [operational, described_class.unknown(printer_id: other_printer.id)]
      end

      it 'does not call Redis without printers' do
        expect(redis).not_to receive(:mget)

        expect(described_class.where(printer_id: [])).to eq []
      end

      it 'skips unreadable snapshots' do
        redis.set("printer_status:#{other_printer.id}", 'not json')

        expect(described_class.where(printer_id: [printer.id, other_printer.id])).to eq [operational]
      end

      it 'skips incomplete snapshots, and unknown state families' do
        redis.set("printer_status:#{other_printer.id}", { printer_id: other_printer.id }.to_json)
        redis.set("printer_status:#{printer.id}",
                  { printer_id: printer.id, state_family: 'NEW', state_text: 'x' }.to_json)

        expect(described_class.where(printer_id: [printer.id, other_printer.id])).to eq []
      end

      it 'skips snapshots with an unknown or a missing temperature unit' do
        snapshot = JSON.parse(operational.to_json)
        redis.set("printer_status:#{printer.id}",
                  snapshot.merge('hotend' => { actual: 210.0, unit: 'RANKINE' }).to_json)
        redis.set("printer_status:#{other_printer.id}",
                  snapshot.merge('printer_id' => other_printer.id, 'bed' => { actual: 60.0, unit: nil }).to_json)

        expect(described_class.where(printer_id: [printer.id, other_printer.id])).to eq []
      end
    end

    describe '.find_by' do
      it 'reads one snapshot' do
        operational.save!

        expect(described_class.find_by(printer_id: printer.id)).to eq operational
        expect(described_class.find_by(printer_id: other_printer.id)).to be_nil
      end

      it 'skips a snapshot with an unknown temperature unit, with a warning' do
        snapshot = JSON.parse(operational.to_json).merge('bed' => { actual: 60.0, unit: 'kelvin' })
        redis.set("printer_status:#{printer.id}", snapshot.to_json)
        allow(Rails.logger).to receive(:warn)

        expect(described_class.find_by(printer_id: printer.id)).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/Ignoring unreadable snapshot for printer #{printer.id}/)
      end
    end

    describe '.find_or_initialize_by' do
      it "finds the printer's snapshot, saved as far as #changed? goes" do
        operational.save!

        found = described_class.find_or_initialize_by(printer:)

        expect(found).to eq(operational).and have_attributes(printer:, changed?: false)
      end

      it 'initializes a new one without a snapshot, without saving it' do
        expect(described_class.find_or_initialize_by(printer:))
          .to have_attributes(printer:, printer_id: printer.id, state_family: nil, changed?: true)
        expect(redis.keys).to be_empty
      end
    end

    describe '#changed? after saving' do
      before { allow(TentaclesSchema.subscriptions).to receive(:trigger) }

      it 'is false once saved' do
        operational.save!

        expect(operational).not_to be_changed
      end

      it 'stays true when pushing printerStatusChanged failed, so that the next tick saves it again' do
        allow(TentaclesSchema.subscriptions).to receive(:trigger).and_raise(StandardError, 'ActionCable is down')

        expect { operational.save! }.to raise_error(StandardError, 'ActionCable is down')
        expect(operational).to be_changed
      end
    end

    describe '.delete_by' do
      it 'deletes the snapshots of the printers only' do
        operational.save!
        described_class.unknown(printer_id: other_printer.id).save!

        described_class.delete_by(printer_id: [printer.id])

        expect(redis.keys).to eq ["printer_status:#{other_printer.id}"]
      end
    end
  end
end
