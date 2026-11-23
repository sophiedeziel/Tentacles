# frozen_string_literal: true

require 'rails_helper'
require_relative 'command_shared_examples'

# What every command shares, through Printer::Pause (Printer::Command is abstract)
RSpec.describe Printer::Command do
  include_context 'with a printer command'

  let(:command) { Printer::Pause.new(printer:) }

  before { allow(printer.api).to receive(:pause) }

  it 'is abstract' do
    expect { described_class.new(printer:) }.to raise_error(NotImplementedError, /abstract/)
  end

  it 'exposes the live job it checked' do
    live_job[:job_id] = 7
    command.save!

    expect(command.live_job).to have_attributes(state_family: Printer::StateFamily::Printing,
                                                file_name: 'cube.gcode', job_id: 7)
  end

  describe 'the messages of the printer API and network failures' do
    {
      Printer::Backend::Unreachable.new('Failed to open TCP connection to 10.0.1.165:80') =>
        "Could not reach Prusa MK4's OctoPrint: Failed to open TCP connection to 10.0.1.165:80",
      Printer::Backend::Unauthorized.new('[403] Invalid API key') =>
        "Prusa MK4's OctoPrint returned an error: [403] Invalid API key",
      Printer::Backend::MissingCredentials.new('No URI') => 'Prusa MK4 has no OctoPrint URL or API key',
      Printer::Backend::UnreadableCredentials.new(Printer::Backend::UnreadableCredentials::MESSAGE) =>
        "Prusa MK4's stored OctoPrint API key can't be read, re-enter it",
      Printer::Backend::NoJob.new('No job') => 'Prusa MK4 has no job under way',
      URI::InvalidURIError.new('bad URI(is not URI?): "http://octo pi.local"') =>
        'Prusa MK4 has an invalid OctoPrint URL',
      JSON::ParserError.new("unexpected token at '<html>'") =>
        "Prusa MK4's OctoPrint URL does not answer like OctoPrint",
      KeyError.new('key not found: :error') => "Prusa MK4's OctoPrint URL does not answer like OctoPrint"
    }.each do |error, message|
      it "words #{error.class.name} for the user, without sending the command" do
        allow(printer.api).to receive(:live_job).and_raise(error)

        expect(command.save).to be false
        expect(command.errors.full_messages).to eq([message])
        expect(printer.api).not_to have_received(:pause)
        expect(Printer::Status).not_to have_received(:find_or_initialize_by)
      end
    end

    it 'names the product and the secret of the backend' do
      printer = create(:printer, :prusalink, name: 'Prusa MK4')
      allow(printer.api).to receive(:live_job).and_raise(Printer::Backend::MissingCredentials)
      command = Printer::Pause.new(printer:)

      command.save

      expect(command.errors.full_messages).to eq(['Prusa MK4 has no PrusaLink URL or password'])
    end

    it 'never echoes the secret back' do
      allow(printer.api).to receive(:live_job)
        .and_raise(Printer::Backend::Unreachable, "Failed with key #{printer.secret}")

      command.save

      expect(command.errors.full_messages).to eq(["Could not reach Prusa MK4's OctoPrint: Failed with key [FILTERED]"])
    end

    it 'raises them with save!' do
      allow(printer.api).to receive(:live_job).and_raise(Printer::Backend::Unreachable, 'timeout')

      expect { command.save! }.to raise_error(Printer::Backend::Unreachable, 'timeout')
    end

    it 'raises them from valid?, which reads the live job' do
      allow(printer.api).to receive(:live_job).and_raise(Printer::Backend::Unreachable, 'timeout')

      expect { command.valid? }.to raise_error(Printer::Backend::Unreachable, 'timeout')
    end

    it 'raises the other errors' do
      allow(printer.api).to receive(:live_job).and_raise(ArgumentError, 'bug')

      expect { command.save }.to raise_error(ArgumentError, 'bug')
    end
  end
  # One monitor tick, inline, after the command (see Printer::Command#refresh_status): never raises, so the command
  # still succeeds when the printer or Redis can't be reached
  describe 'the inline status refresh' do
    let(:redis) { MockRedis.new }
    let(:subscriptions) { instance_double(GraphQL::Subscriptions, trigger: nil) }

    let(:job) do
      Octoprint::Job.deserialize({ state: 'Paused', job: { file: { name: 'cube.gcode' } },
                                   progress: { completion: 40.0, print_time_left: 1800.0 } })
    end
    let(:printer_state) do
      Octoprint::Printer.deserialize({ temperature: { tool0: { actual: 200.0, target: 210.0 },
                                                      bed: { actual: 60.0, target: 60.0 } } })
    end
    let(:camera) { Printer::Status::Camera.new(enabled: true, stream_url: 'http://10.0.1.165/webcam/?action=stream') }
    let(:previous) do
      Printer::Status.new(printer_id: printer.id, state_family: Printer::StateFamily::Printing, state_text: 'Printing',
                          file_name: 'cube.gcode', progress: 39.0, camera:, last_seen_at: 1.minute.ago,
                          updated_at: 1.minute.ago)
    end

    let(:status) { Printer::Status.find_by(printer_id: printer.id) }

    before do
      stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
      allow(TentaclesSchema).to receive(:subscriptions).and_return(subscriptions)
      allow(Printer::Status).to receive(:find_or_initialize_by).and_call_original
      allow(Octoprint::Job).to receive(:get) { job }
      allow(Octoprint::Printer).to receive(:get) { printer_state }
      allow(Octoprint::Settings).to receive(:webcam)
    end

    context 'with a previous snapshot' do
      before { redis.set(Printer::Status.key(printer.id), previous.to_json) }

      it 'writes the new snapshot to Redis' do
        command.save!

        expect(status).to have_attributes(
          printer_id: printer.id, state_family: Printer::StateFamily::Paused, state_text: 'Paused',
          file_name: 'cube.gcode', progress: 40.0, print_time_left: 1800
        )
        expect(status.hotend&.as_json).to eq('actual' => 200.0, 'target' => 210.0, 'unit' => 'CELSIUS')
      end

      it 'triggers the subscription once' do
        command.save!
        expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
      end

      it "keeps the previous snapshot's camera without reading the webcam settings" do
        command.save!
        expect(status.camera).to eq camera
        expect(Octoprint::Settings).not_to have_received(:webcam)
      end
    end

    context 'without a previous snapshot' do
      it 'writes a snapshot with a disabled camera' do
        command.save!
        expect(status).to have_attributes(state_family: Printer::StateFamily::Paused,
                                          camera: Printer::Status::Camera.new)
        expect(subscriptions).to have_received(:trigger).once
      end
    end

    context 'when the snapshot did not change' do
      before { Printer::Pause.new(printer:).save! }

      it 'neither writes nor triggers again' do
        allow(redis).to receive(:set).and_call_original

        command.save!

        expect(status).to have_attributes(state_family: Printer::StateFamily::Paused)
        expect(redis).not_to have_received(:set)
        expect(subscriptions).to have_received(:trigger).once
      end
    end

    context 'when OctoPrint is unreachable' do
      before do
        redis.set(Printer::Status.key(printer.id), previous.to_json)
        allow(Octoprint::Job).to receive(:get).and_raise(Octoprint::Exceptions::ConnectionError, 'Failed to open TCP')
      end

      it 'succeeds without publishing, and keeps the snapshot' do
        expect(command.save).to be true
        expect(status).to have_attributes(state_family: Printer::StateFamily::Printing)
        expect(subscriptions).not_to have_received(:trigger)
      end

      it 'logs a warning' do
        allow(Rails.logger).to receive(:warn).and_call_original
        command.save!
        expect(Rails.logger).to have_received(:warn)
          .with(/\[Printer::Pause\] Prusa MK4 \(##{printer.id}\): Inline refresh failed: .*Unreachable: Failed/)
      end
    end

    context 'when the printer has no OctoPrint credentials' do
      let(:printer) { create(:printer, :unvalidated, name: 'Prusa MK4', uri: '', secret: nil) }

      it 'succeeds without reading OctoPrint' do
        expect(command.save).to be true
        expect(Octoprint::Job).not_to have_received(:get)
      end
    end

    context 'when Redis is down' do
      before { allow(redis).to receive(:mget).and_raise(Redis::CannotConnectError) }

      it 'succeeds without publishing' do
        expect(command.save).to be true
        expect(subscriptions).not_to have_received(:trigger)
      end
    end

    context 'when Redis fails while writing' do
      before { allow(redis).to receive(:set).and_raise(Redis::CannotConnectError) }

      it 'succeeds without triggering' do
        expect(command.save).to be true
        expect(subscriptions).not_to have_received(:trigger)
      end
    end
  end
end
