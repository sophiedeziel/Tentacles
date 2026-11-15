# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterMonitor do
  let(:redis) { MockRedis.new }
  let(:printer) { create(:printer) }
  let(:subscriptions) { instance_double(GraphQL::Subscriptions, trigger: nil) }

  let(:job) do
    Octoprint::Job.deserialize({ state: 'Paused', job: { file: { name: 'cube.gcode' } },
                                 progress: { completion: 40.0, print_time_left: 1800.0 } })
  end
  let(:printer_state) do
    Octoprint::Printer.deserialize({ temperature: { tool0: { actual: 200.0, target: 210.0 },
                                                    bed: { actual: 60.0, target: 60.0 } } })
  end
  let(:camera) { PrinterStatus::Camera.new(enabled: true, stream_url: 'http://10.0.1.165/webcam/?action=stream') }
  let(:previous) do
    PrinterStatus.new(printer_id: printer.id, state_family: PrinterStateFamily::Printing, state_text: 'Printing',
                      file_name: 'cube.gcode', progress: 39.0, camera:, last_seen_at: 1.minute.ago,
                      updated_at: 1.minute.ago)
  end

  let(:status) { PrinterStatusStore.read(printer.id) }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(TentaclesSchema).to receive(:subscriptions).and_return(subscriptions)
    allow(Octoprint::Job).to receive(:get) { job }
    allow(Octoprint::Printer).to receive(:get) { printer_state }
    allow(Octoprint::Settings).to receive(:webcam)
  end

  describe '.publish' do
    it 'writes the snapshot to Redis and notifies the subscribers' do
      described_class.publish(previous, printer)

      expect(status).to have_attributes(state_family: PrinterStateFamily::Printing, progress: 39.0)
      expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
    end
  end

  describe '.refresh' do
    subject(:refresh) { described_class.refresh(printer) }

    context 'with a previous snapshot' do
      before { PrinterStatusStore.write(previous) }

      it 'writes the new snapshot to Redis and returns it' do
        expect(refresh).to have_attributes(
          printer_id: printer.id, state_family: PrinterStateFamily::Paused, state_text: 'Paused',
          file_name: 'cube.gcode', progress: 40.0, print_time_left: 1800
        )
        expect(status).to have_attributes(state_family: PrinterStateFamily::Paused, progress: 40.0)
        expect(status.hotend&.serialize).to eq('actual' => 200.0, 'target' => 210.0, 'unit' => 'CELSIUS')
      end

      it 'triggers the subscription once' do
        refresh
        expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
      end

      it "keeps the previous snapshot's camera without reading the webcam settings" do
        refresh
        expect(status.camera).to eq camera
        expect(Octoprint::Settings).not_to have_received(:webcam)
      end

      it 'records the last time the printer was seen' do
        expect(refresh.last_seen_at).to be_within(1.second).of(Time.current)
      end

      it "uses the printer's own client without touching the global configuration" do
        allow(Octoprint).to receive(:configure)
        clients = []
        allow(Octoprint::Job).to receive(:get) { clients << Octoprint.client and job }

        refresh

        expect(clients).to eq [printer.api.client]
        expect(Octoprint).not_to have_received(:configure)
      end
    end

    context 'without a previous snapshot' do
      it 'writes a snapshot with a disabled camera' do
        refresh
        expect(status).to have_attributes(state_family: PrinterStateFamily::Paused,
                                          camera: PrinterStatus::Camera.new)
        expect(subscriptions).to have_received(:trigger).once
      end
    end

    context 'when the snapshot did not change' do
      before { described_class.refresh(printer) }

      it 'returns it without writing or triggering again' do
        allow(PrinterStatusStore).to receive(:write)

        expect(refresh).to have_attributes(state_family: PrinterStateFamily::Paused)
        expect(PrinterStatusStore).not_to have_received(:write)
        expect(subscriptions).to have_received(:trigger).once
      end
    end

    context 'when OctoPrint is unreachable' do
      before do
        PrinterStatusStore.write(previous)
        allow(Octoprint::Job).to receive(:get).and_raise(Octoprint::Exceptions::ConnectionError, 'Failed to open TCP')
      end

      it 'returns nil without raising, nor publishing' do
        expect(refresh).to be_nil
        expect(status).to have_attributes(state_family: PrinterStateFamily::Printing)
        expect(subscriptions).not_to have_received(:trigger)
      end

      it 'logs a warning' do
        allow(Rails.logger).to receive(:warn).and_call_original
        refresh
        expect(Rails.logger).to have_received(:warn).with(/Inline refresh failed: .*Unreachable: Failed/)
      end
    end

    context 'when the printer has no OctoPrint credentials' do
      let(:printer) { create(:printer, :unvalidated, uri: '', secret: nil) }

      it 'returns nil without raising' do
        expect(refresh).to be_nil
        expect(Octoprint::Job).not_to have_received(:get)
      end
    end

    context 'when Redis is down' do
      before { allow(redis).to receive(:mget).and_raise(Redis::CannotConnectError) }

      it 'returns nil without raising' do
        expect(refresh).to be_nil
        expect(subscriptions).not_to have_received(:trigger)
      end
    end

    context 'when Redis fails while writing' do
      before { allow(redis).to receive(:set).and_raise(Redis::CannotConnectError) }

      it 'returns nil without raising nor triggering' do
        expect(refresh).to be_nil
        expect(subscriptions).not_to have_received(:trigger)
      end
    end
  end
end
