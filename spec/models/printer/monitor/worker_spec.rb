# frozen_string_literal: true

require 'rails_helper'
require 'support/unreadable_secret'

RSpec.describe Printer::Monitor::Worker do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }
  let(:printer) { create(:printer) }
  let(:worker) { described_class.new(printer:, interval: 2.0) }
  let(:subscriptions) { instance_double(GraphQL::Subscriptions, trigger: nil) }

  let(:job_state) { 'Printing' }
  let(:completion) { 12.5 }
  let(:hotend_actual) { 200.1 }
  let(:job) do
    Octoprint::Job.deserialize({ state: job_state, job: { file: { name: 'cube.gcode' } },
                                 progress: { completion:, print_time_left: 3600.0 } })
  end
  let(:printer_state) do
    Octoprint::Printer.deserialize({ temperature: { tool0: { actual: hotend_actual, target: 210.0 },
                                                    bed: { actual: 60.0, target: 60.0 } } })
  end
  let(:webcam) do
    Octoprint::Settings::Webcam.from_settings(
      { webcam: { webcam_enabled: true, stream_url: '/webcam/?action=stream' } }
    )
  end

  let(:status) { Printer::Status.find_by(printer_id: printer.id) }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(TentaclesSchema).to receive(:subscriptions).and_return(subscriptions)
    allow(Octoprint::Job).to receive(:get) { job }
    allow(Octoprint::Printer).to receive(:get) { printer_state }
    allow(Octoprint::Settings).to receive(:webcam) { webcam }
  end

  def go_offline(error = Octoprint::Exceptions::ConnectionError.new('Failed to open TCP connection'))
    allow(Octoprint::Job).to receive(:get).and_raise(error)
  end

  describe '.default_interval' do
    it 'defaults to 2 seconds' do
      expect(described_class.default_interval).to eq 2.0
    end

    it 'reads PRINTER_MONITOR_INTERVAL' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('PRINTER_MONITOR_INTERVAL', anything).and_return('5')
      expect(described_class.default_interval).to eq 5.0
    end
  end

  it 'raises for an unknown backend when built, so that the Supervisor skips the printer' do
    printer = build(:printer, backend: 'repetier')
    expect { described_class.new(printer:) }.to raise_error(ArgumentError, 'Unknown printer backend "repetier"')
  end

  it 'defaults to the interval from PRINTER_MONITOR_INTERVAL' do
    expect(described_class.new(printer:).interval).to eq 2.0
  end

  describe '#tick' do
    context 'when the printer is printing' do
      before { worker.tick }

      it 'writes the snapshot to Redis' do
        expect(status).to have_attributes(
          printer_id: printer.id, state_family: Printer::StateFamily::Printing, state_text: 'Printing',
          error_text: nil, file_name: 'cube.gcode', progress: 12.5, print_time_left: 3600
        )
      end

      it 'reads the temperatures' do
        expect(status.hotend&.as_json).to eq('actual' => 200.1, 'target' => 210.0, 'unit' => 'CELSIUS')
        expect(status.bed&.as_json).to eq('actual' => 60.0, 'target' => 60.0, 'unit' => 'CELSIUS')
      end

      it 'excludes the SD card and state from the printer request' do
        expect(Octoprint::Printer).to have_received(:get).with(exclude: %i[sd state])
      end

      it 'triggers the subscription once' do
        expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
      end

      it 'resolves the relative webcam URL against the OctoPrint URI' do
        expect(status.camera.as_json).to eq('enabled' => true, 'stream_url' => 'http://10.0.1.165/webcam/?action=stream')
      end

      it 'records the last time the printer was seen' do
        expect(status.last_seen_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'uses its own client without touching the global configuration' do
      allow(Octoprint).to receive(:configure)
      clients = []
      allow(Octoprint::Job).to receive(:get) { clients << Octoprint.client and job }

      worker.tick

      expect(clients.first).to have_attributes(host: printer.uri, api_key: printer.secret)
      expect(Octoprint).not_to have_received(:configure)
    end

    it 'writes the heartbeat' do
      freeze_time do
        worker.tick
        expect(Printer::Monitor::Heartbeat.last&.at).to be_within(0.001).of(Time.current)
      end
    end

    it 'writes the heartbeat when OctoPrint is unreachable' do
      go_offline
      worker.tick
      expect(Printer::Monitor::Heartbeat.healthy?).to be true
    end

    context 'when the state did not change' do
      before { worker.tick }

      it 'does not write or trigger again, even with small jitter' do
        allow(redis).to receive(:set).and_call_original
        allow(Octoprint::Job).to receive(:get) do
          Octoprint::Job.deserialize({ state: 'Printing', job: { file: { name: 'cube.gcode' } },
                                       progress: { completion: 12.7, print_time_left: 3590.0 } })
        end
        allow(Octoprint::Printer).to receive(:get) do
          Octoprint::Printer.deserialize({ temperature: { tool0: { actual: 199.8, target: 210.0 },
                                                          bed: { actual: 60.2, target: 60.0 } } })
        end

        worker.tick

        expect(redis).not_to have_received(:set).with(Printer::Status.key(printer.id), anything)
        expect(subscriptions).to have_received(:trigger).once
      end
    end

    context 'when the state changed' do
      before { worker.tick }

      it 'writes the new snapshot and triggers once more' do
        allow(Octoprint::Job).to receive(:get) do
          Octoprint::Job.deserialize({ state: 'Paused', job: { file: {} }, progress: { completion: 40.0 } })
        end

        worker.tick

        expect(status).to have_attributes(state_family: Printer::StateFamily::Paused, progress: 40.0)
        expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).twice
      end
    end

    context 'when OctoPrint is not connected to the printer' do
      %w[Offline Connecting].each do |state|
        context "with the #{state} state" do
          let(:job_state) { state }

          before { worker.tick }

          it 'does not read the temperatures' do
            expect(Octoprint::Printer).not_to have_received(:get)
          end

          it { expect(status).to have_attributes(state_text: state, hotend: nil, bed: nil) }
        end
      end
    end

    context 'when reading the temperatures conflicts' do
      before do
        allow(Octoprint::Printer).to receive(:get)
          .and_raise(Octoprint::Exceptions::ConflictError, '[409] Not operational')
        worker.tick
      end

      it 'publishes the snapshot without temperatures' do
        expect(status).to have_attributes(state_family: Printer::StateFamily::Printing, hotend: nil, bed: nil)
      end

      it 'does not count as a failure' do
        expect(worker.delay).to eq 2.0
      end
    end

    context 'when reading the temperatures fails with another OctoPrint error' do
      before do
        allow(Octoprint::Printer).to receive(:get).and_raise(Octoprint::Exceptions::InternalServerError, '[500] Oops')
        worker.tick
      end

      it { expect(status).to have_attributes(state_family: Printer::StateFamily::Printing, hotend: nil, bed: nil) }

      it 'logs the error only when it starts failing' do
        allow(Rails.logger).to receive(:error).and_call_original
        2.times { worker.tick }
        allow(Octoprint::Printer).to receive(:get) { printer_state }
        worker.tick
        allow(Octoprint::Printer).to receive(:get).and_raise(Octoprint::Exceptions::InternalServerError, '[500] Oops')
        2.times { worker.tick }

        expect(Rails.logger).to have_received(:error).with(/Failed to read the temperatures/).once
      end
    end

    [JSON::ParserError.new("unexpected token at '<html>'"), KeyError.new('key not found: :error')].each do |error|
      context "when a server that isn't OctoPrint answers the temperatures request (#{error.class})" do
        before do
          allow(Octoprint::Printer).to receive(:get).and_raise(error)
          worker.tick
        end

        it { expect(status).to have_attributes(state_family: Printer::StateFamily::Printing, hotend: nil, bed: nil) }
      end
    end

    context 'when OctoPrint returns very long texts' do
      let(:long) { 'x' * 1000 }
      let(:job) do
        Octoprint::Job.deserialize({ state: "Printing #{long}", error: long, job: { file: { name: long } } })
      end

      before { worker.tick }

      it 'truncates them to 255 characters' do
        expect([status.state_text, status.error_text, status.file_name].map(&:length)).to eq [255, 255, 255]
        expect(status.state_family).to eq Printer::StateFamily::Printing
      end
    end

    context 'when the connection drops while reading the temperatures' do
      before do
        allow(Octoprint::Printer).to receive(:get).and_raise(Octoprint::Exceptions::TimeoutError, 'execution expired')
        worker.tick
      end

      it { expect(status).to have_attributes(state_family: Printer::StateFamily::Offline, state_text: 'Unreachable') }
    end

    context 'when OctoPrint is unreachable' do
      before { go_offline }

      it 'publishes an OFFLINE snapshot' do
        worker.tick

        expect(status).to have_attributes(
          state_family: Printer::StateFamily::Offline, state_text: 'Unreachable',
          error_text: 'Failed to open TCP connection', file_name: nil, progress: nil, hotend: nil, bed: nil,
          server_reachable?: false
        )
      end

      it 'triggers once, not on every tick' do
        3.times { worker.tick }
        expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
      end

      it 'backs off exponentially, up to 30 seconds' do
        delays = Array.new(6) do
          worker.tick
          worker.delay
        end
        expect(delays).to eq [2.0, 4.0, 8.0, 16.0, 30.0, 30.0]
      end

      it 'goes back to the interval after a success' do
        3.times { worker.tick }
        allow(Octoprint::Job).to receive(:get) { job }
        worker.tick
        expect(worker.delay).to eq 2.0
      end

      it 'keeps the printer last_seen_at from the database' do
        seen_at = 1.day.ago.change(usec: 0)
        printer.update!(last_seen_at: seen_at)
        worker.tick
        expect(status.last_seen_at).to eq seen_at
        expect(printer.reload.last_seen_at).to eq seen_at
      end
    end

    context 'when OctoPrint becomes unreachable after being online' do
      it 'saves the last time it was seen on the first failed tick' do
        seen_at = Time.zone.local(2026, 11, 15, 10, 0, 0)
        travel_to(seen_at) { worker.tick }
        printer.update_column(:last_seen_at, nil) # rubocop:disable Rails/SkipsModelValidations

        go_offline
        travel_to(seen_at + 30.seconds) { worker.tick }

        expect(printer.reload.last_seen_at).to eq seen_at
        expect(status).to have_attributes(state_family: Printer::StateFamily::Offline, last_seen_at: seen_at)
        expect(subscriptions).to have_received(:trigger).twice
      end

      it 'keeps the last known camera' do
        worker.tick
        go_offline
        worker.tick
        expect(status.camera.stream_url).to eq 'http://10.0.1.165/webcam/?action=stream'
      end

      it 'drops the job and the temperatures of the last snapshot' do
        worker.tick
        go_offline
        worker.tick
        expect(status).to have_attributes(state_family: Printer::StateFamily::Offline, file_name: nil, progress: nil,
                                          print_time_left: nil, hotend: nil, bed: nil)
      end

      it 'publishes the printer again once it answers' do
        worker.tick
        go_offline
        worker.tick
        allow(Octoprint::Job).to receive(:get) { job }
        worker.tick

        expect(status).to have_attributes(state_family: Printer::StateFamily::Printing, error_text: nil,
                                          file_name: 'cube.gcode')
        expect(subscriptions).to have_received(:trigger).exactly(3).times
      end
    end

    context 'when the API key is rejected' do
      before do
        go_offline(Octoprint::Exceptions::AuthenticationError.new('[403] Invalid API key'))
        worker.tick
      end

      it { expect(status).to have_attributes(state_family: Printer::StateFamily::Offline, error_text: '[403] Invalid API key') }
    end

    context 'when the printer has no OctoPrint credentials' do
      let(:printer) { create(:printer, :unvalidated, uri: '', secret: nil) }

      before { worker.tick }

      it 'publishes an OFFLINE snapshot' do
        expect(status).to have_attributes(state_family: Printer::StateFamily::Offline,
                                          error_text: 'Missing OctoPrint credentials')
      end

      it { expect(Octoprint::Job).not_to have_received(:get) }
    end

    context 'when the stored secret cannot be decrypted' do
      include UnreadableSecret

      let(:printer) { make_secret_unreadable(create(:printer)) }

      before { worker.tick }

      it 'publishes an OFFLINE snapshot asking for the credentials' do
        expect(status).to have_attributes(state_family: Printer::StateFamily::Offline,
                                          error_text: "Stored credentials can't be read, re-enter them")
      end

      it { expect(Octoprint::Job).not_to have_received(:get) }
    end

    context 'when something unexpected happens' do
      before do
        allow(Octoprint::Job).to receive(:get).and_raise(NoMethodError, 'undefined method')
      end

      it 'does not raise and publishes an OFFLINE snapshot' do
        expect { worker.tick }.not_to raise_error
        expect(status).to have_attributes(state_family: Printer::StateFamily::Offline, error_text: 'undefined method')
      end
    end

    context 'when Redis is down' do
      before { allow(redis).to receive(:set).and_raise(Redis::CannotConnectError) }

      it 'does not raise' do
        expect { worker.tick }.not_to raise_error
      end

      it 'backs off exponentially over consecutive failed ticks' do
        delays = Array.new(6) do
          worker.tick
          worker.delay
        end
        expect(delays).to eq [2.0, 4.0, 8.0, 16.0, 30.0, 30.0]
      end

      it 'goes back to the interval after a good tick' do
        3.times { worker.tick }
        allow(redis).to receive(:set).and_call_original
        worker.tick

        expect(worker.delay).to eq 2.0
        expect(status).to have_attributes(state_family: Printer::StateFamily::Printing)
      end

      it 'logs only the first failure of the streak' do
        allow(Rails.logger).to receive(:error).and_call_original
        3.times { worker.tick }
        expect(Rails.logger).to have_received(:error).with(/Failed to publish the printer status/).once
      end
    end

    context 'when the GraphQL trigger fails' do
      before { allow(subscriptions).to receive(:trigger).and_raise(StandardError, 'ActionCable is down') }

      it 'still writes the heartbeat and backs off' do
        worker.tick
        expect(Printer::Monitor::Heartbeat.healthy?).to be true
        expect(worker.connectivity.publish_failures).to eq 1
      end
    end
  end

  describe 'webcam settings' do
    it 'are not fetched again within 10 minutes' do
      worker.tick
      travel(9.minutes) { worker.tick }
      expect(Octoprint::Settings).to have_received(:webcam).once
    end

    it 'are fetched again after 10 minutes' do
      worker.tick
      travel(10.minutes + 1.second) { worker.tick }
      expect(Octoprint::Settings).to have_received(:webcam).twice
    end

    it 'are fetched again when OctoPrint answers again' do
      worker.tick
      allow(Octoprint::Job).to receive(:get).and_raise(Octoprint::Exceptions::ConnectionError, 'down')
      worker.tick
      allow(Octoprint::Job).to receive(:get) { job }
      worker.tick
      expect(Octoprint::Settings).to have_received(:webcam).twice
    end

    context 'when they cannot be read' do
      before do
        allow(Octoprint::Settings).to receive(:webcam).and_raise(Octoprint::Exceptions::AuthenticationError, '[403]')
      end

      it 'does not make the printer offline' do
        worker.tick
        expect(status.state_family).to eq Printer::StateFamily::Printing
        expect(status.camera.as_json).to eq('enabled' => false, 'stream_url' => nil)
      end

      it 'keeps the last known camera and retries 10 minutes later' do
        allow(Octoprint::Settings).to receive(:webcam) { webcam }
        worker.tick
        allow(Octoprint::Settings).to receive(:webcam).and_raise(Octoprint::Exceptions::AuthenticationError, '[403]')

        travel(10.minutes + 1.second) { worker.tick }
        travel(15.minutes) { worker.tick }
        travel(20.minutes + 2.seconds) { worker.tick }

        expect(status.camera.stream_url).to eq 'http://10.0.1.165/webcam/?action=stream'
        expect(Octoprint::Settings).to have_received(:webcam).exactly(3).times
      end
    end

    [JSON::ParserError.new("unexpected token at '<html>'"), KeyError.new('key not found: :error')].each do |error|
      context "when a server that isn't OctoPrint answers (#{error.class})" do
        before { allow(Octoprint::Settings).to receive(:webcam).and_raise(error) }

        it 'does not make the printer offline' do
          worker.tick
          expect(status.state_family).to eq Printer::StateFamily::Printing
          expect(status.camera.as_json).to eq('enabled' => false, 'stream_url' => nil)
        end
      end
    end

    {
      'http://cam.local:8080/stream' => 'http://cam.local:8080/stream',
      'webcam/?action=stream' => 'http://10.0.1.165/webcam/?action=stream',
      'rtsp://10.0.1.165/stream' => nil,
      'http://[invalid' => nil
    }.each do |stream_url, expected|
      it "resolves #{stream_url.inspect} to #{expected.inspect}" do
        allow(Octoprint::Settings).to receive(:webcam) do
          Octoprint::Settings::Webcam.from_settings({ webcam: { webcam_enabled: true, stream_url: } })
        end
        worker.tick
        expect(status.camera.stream_url).to eq expected
      end
    end

    context 'when the OctoPrint URI has a path without a trailing slash' do
      let(:printer) { create(:printer, uri: 'http://10.0.1.165/octoprint') }

      it 'resolves relative URLs under that path' do
        allow(Octoprint::Settings).to receive(:webcam) do
          Octoprint::Settings::Webcam.from_settings({ webcam: { webcam_enabled: true, stream_url: 'webcam/' } })
        end
        worker.tick
        expect(status.camera.stream_url).to eq 'http://10.0.1.165/octoprint/webcam/'
      end
    end

    context 'when the OctoPrint URI has credentials' do
      let(:printer) { create(:printer, uri: 'http://admin:secret@10.0.1.165/') }

      it 'does not copy them into the stream URL' do
        worker.tick
        expect(status.camera.stream_url).to eq 'http://10.0.1.165/webcam/?action=stream'
      end

      it 'strips them from absolute stream URLs too' do
        allow(Octoprint::Settings).to receive(:webcam) do
          Octoprint::Settings::Webcam.from_settings(
            { webcam: { webcam_enabled: true, stream_url: 'http://bob:pw@cam.local/stream' } }
          )
        end
        worker.tick
        expect(status.camera.stream_url).to eq 'http://cam.local/stream'
      end
    end
  end

  describe 'blank specs' do
    before { allow(Rails.logger).to receive(:info).and_call_original }

    it 'enqueues FillPrinterSpecsJob on the first tick the printer answers, not on every tick' do
      expect { 3.times { worker.tick } }.to have_enqueued_job(FillPrinterSpecsJob).with(printer.id).exactly(:once)
      expect(Rails.logger).to have_received(:info)
        .with(/Filling its blank specs in the background: it answered, and no fill has read its server yet/)
    end

    it 'waits for the printer to answer' do
      go_offline
      expect { 2.times { worker.tick } }.not_to have_enqueued_job(FillPrinterSpecsJob)

      allow(Octoprint::Job).to receive(:get) { job }
      expect { worker.tick }.to have_enqueued_job(FillPrinterSpecsJob).with(printer.id)
    end

    it 'does not enqueue it when a fill already read the server, even since the worker started' do
      worker
      Printer.find(printer.id).update!(specs_filled_at: Time.current)

      expect { 2.times { worker.tick } }.not_to have_enqueued_job(FillPrinterSpecsJob)
    end

    it 'enqueues it again once the worker restarts, e.g. after the credentials changed' do
      worker.tick
      expect { described_class.new(printer:, interval: 2.0).tick }
        .to have_enqueued_job(FillPrinterSpecsJob).with(printer.id)
    end

    it 'keeps polling, and logs once, when it cannot be enqueued' do
      allow(FillPrinterSpecsJob).to receive(:perform_later).and_raise(RedisClient::CannotConnectError, 'refused')
      allow(Rails.logger).to receive(:error).and_call_original

      expect { 2.times { worker.tick } }.not_to raise_error
      expect(status).to have_attributes(state_family: Printer::StateFamily::Printing)
      expect(worker.delay).to eq 2.0
      expect(Rails.logger).to have_received(:error).with(/Failed to enqueue FillPrinterSpecsJob/).once
    end
  end

  describe 'printers.last_seen_at' do
    let(:start) { Time.zone.local(2026, 11, 15, 10, 0, 0) }

    it 'is saved at most once a minute while online' do
      travel_to(start) { worker.tick }
      expect(printer.reload.last_seen_at).to eq start

      travel_to(start + 30.seconds) { worker.tick }
      expect(printer.reload.last_seen_at).to eq start

      travel_to(start + 61.seconds) { worker.tick }
      expect(printer.reload.last_seen_at).to eq start + 61.seconds
    end
  end

  describe 'thread' do
    it 'ticks until stopped' do
      ticked = Queue.new
      allow(worker).to receive(:tick) { ticked << true }

      worker.start
      ticked.pop(timeout: 5)
      worker.stop

      expect(worker.join(5)).to be_a(Thread)
      expect(worker).to have_received(:tick).at_least(:once)
    end
  end

  describe 'failure logs' do
    before do
      allow(Rails.logger).to receive(:warn).and_call_original
      allow(Rails.logger).to receive(:error).and_call_original
    end

    [
      Octoprint::Exceptions::ConnectionError.new('Failed to open TCP connection'),
      Octoprint::Exceptions::TimeoutError.new('execution expired'),
      Octoprint::Exceptions::AuthenticationError.new('[403] Invalid API key'),
      Octoprint::Exceptions::InternalServerError.new('[500] Oops')
    ].each do |error|
      it "warns once that the printer is unreachable when OctoPrint raises #{error.class.name.demodulize}" do
        go_offline(error)
        2.times { worker.tick }

        expect(Rails.logger).to have_received(:warn).with(/Unreachable: #{Regexp.escape(error.message)}/).once
        expect(Rails.logger).not_to have_received(:error).with(/Unexpected error/)
      end
    end

    it 'warns about missing credentials' do
      printer = create(:printer, :disconnected)
      described_class.new(printer:, interval: 2.0).tick

      expect(Rails.logger).to have_received(:warn).with(/Unreachable: Missing OctoPrint credentials/)
    end

    it 'logs anything else as an unexpected error' do
      go_offline(NoMethodError.new('undefined method'))
      worker.tick

      expect(Rails.logger).to have_received(:error)
        .with(/Unexpected error while polling OctoPrint: NoMethodError: undefined method/)
    end
  end

  context 'with a PrusaLink printer' do
    let(:printer) { create(:printer, :prusalink) }
    let(:prusalink_status) do
      Prusalink::Status.deserialize({ printer: { state: 'PRINTING', temp_nozzle: 215.0, target_nozzle: 215.0,
                                                 temp_bed: 60.0, target_bed: 60.0 },
                                      job: { id: 7, progress: 42.0, time_remaining: 600 } })
    end

    before do
      allow(Prusalink::Status).to receive(:get) { prusalink_status }
      allow(Prusalink::Job).to receive(:get) do
        Prusalink::Job.deserialize({ id: 7, state: 'PRINTING',
                                     file: { name: 'CUBE~1.BGC', display_name: 'cube.bgcode' } })
      end
      allow(Rails.logger).to receive(:warn).and_call_original
      allow(Rails.logger).to receive(:error).and_call_original
    end

    it 'publishes the snapshot read from PrusaLink, without a camera' do
      worker.tick

      expect(status).to have_attributes(
        printer_id: printer.id, state_family: Printer::StateFamily::Printing, state_text: 'Printing',
        file_name: 'cube.bgcode', progress: 42.0, print_time_left: 600,
        camera: Printer::Status::Camera.new(enabled: false)
      )
      expect(Octoprint::Job).not_to have_received(:get)
      expect(Octoprint::Settings).not_to have_received(:webcam)
    end

    it 'publishes an OFFLINE snapshot when PrusaLink is unreachable' do
      allow(Prusalink::Status).to receive(:get).and_raise(Prusalink::Exceptions::ConnectionError, 'Connection refused')
      worker.tick

      expect(status).to have_attributes(state_family: Printer::StateFamily::Offline, state_text: 'Unreachable',
                                        error_text: 'Connection refused')
    end

    context 'without a password' do
      let(:printer) { create(:printer, :prusalink, :unvalidated, secret: nil) }

      it 'says the PrusaLink credentials are missing' do
        worker.tick

        expect(status).to have_attributes(state_family: Printer::StateFamily::Offline,
                                          error_text: 'Missing PrusaLink credentials')
        expect(Rails.logger).to have_received(:warn).with(/Unreachable: Missing PrusaLink credentials/)
        expect(Prusalink::Status).not_to have_received(:get)
      end
    end

    it 'names PrusaLink in the unexpected errors' do
      allow(Prusalink::Status).to receive(:get).and_raise(NoMethodError, 'undefined method')
      worker.tick

      expect(Rails.logger).to have_received(:error)
        .with(/Unexpected error while polling PrusaLink: NoMethodError: undefined method/)
    end
  end
end
