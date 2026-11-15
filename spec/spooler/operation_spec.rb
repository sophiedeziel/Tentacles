# frozen_string_literal: true

require 'rails_helper'
require 'spooler'

RSpec.describe Spooler::Print do
  let(:printer) { create(:printer) }
  let(:printer_job) { create(:printer_job, printer:, status: 'active') }
  let(:operation) { described_class.new(printer, printer_job) }
  let(:subscriptions) { instance_double(GraphQL::Subscriptions, trigger: nil) }
  let(:polls) { [] }

  # Makes Job.get return one job per state, in order, and records the state of each poll
  def octoprint_states(*states, completion: 42.1)
    jobs = states.map do |state|
      Octoprint::Job.deserialize({ state:, job: { file: { name: 'cube.gcode' } }, progress: { completion: } })
    end
    allow(Octoprint::Job).to receive(:get) do
      jobs.shift.tap { |job| polls << job.state }
    end
  end

  before do
    allow(TentaclesSchema).to receive(:subscriptions).and_return(subscriptions)
    allow(UploadFilesToPrintersJob).to receive(:perform_now)
    allow(operation).to receive(:sleep)
    allow(operation).to receive(:log)
  end

  describe '#execute' do
    it 'uploads the file to the printer and starts the print' do
      octoprint_states('Printing', 'Operational')
      operation.execute
      expect(UploadFilesToPrintersJob).to have_received(:perform_now)
        .with([printer_job.executable_id], [printer.id], print: true)
    end

    it 'waits for the print to start: the printer can still be operational right after the upload' do
      octoprint_states('Operational', 'Operational', 'Printing', 'Operational')
      operation.execute
      expect(polls).to eq %w[Operational Operational Printing Operational]
    end

    it 'stops waiting when the print has not started after MAX_START_POLLS polls' do
      stub_const('Spooler::Print::MAX_START_POLLS', 3)
      octoprint_states('Operational', 'Operational', 'Operational', 'Printing')
      operation.execute
      expect(polls).to eq %w[Operational Operational Operational]
      expect(operation).to have_received(:log).with(/The print didn't start after 3 polls/)
    end

    ['Offline', 'Error: Printer halted'].each do |state|
      it "does not wait for the print to start when the printer is #{state}" do
        octoprint_states(state, 'Printing')
        operation.execute
        expect(polls).to eq [state]
      end
    end

    it 'raises the errors of the upload: the print cannot start' do
      allow(UploadFilesToPrintersJob).to receive(:perform_now).and_raise(PrinterBackends::Unreachable, 'timeout')
      allow(Octoprint::Job).to receive(:get)

      expect { operation.execute }.to raise_error(PrinterBackends::Unreachable, 'timeout')
      expect(Octoprint::Job).not_to have_received(:get)
    end

    # On main, Spooler::Print passed `select: true, print: true`, which Printer#upload doesn't accept
    it 'calls the upload job with arguments that Printer#upload accepts' do
      allow(UploadFilesToPrintersJob).to receive(:perform_now).and_call_original
      allow(printer.api).to receive(:upload)
      allow(Printer).to receive(:where).and_call_original
      allow(Printer).to receive(:where).with(id: [printer.id]).and_return([printer])
      octoprint_states('Printing', 'Operational')

      expect { operation.execute }.not_to raise_error
      expect(printer.api).to have_received(:upload).with(Rails.root.join('tmp/test.gcode').to_s, print: true)
    end

    it 'keeps monitoring through a pause and a resume' do
      octoprint_states('Printing', 'Pausing', 'Paused', 'Resuming', 'Printing', 'Finishing', 'Operational')
      operation.execute
      expect(polls).to eq %w[Printing Pausing Paused Resuming Printing Finishing Operational]
    end

    it 'keeps monitoring while the print is cancelling' do
      octoprint_states('Printing', 'Cancelling', 'Cancelling', 'Operational')
      operation.execute
      expect(polls).to eq %w[Printing Cancelling Cancelling Operational]
    end

    it 'keeps monitoring while OctoPrint starts the print' do
      octoprint_states('Starting', 'Printing from SD', 'Operational')
      operation.execute
      expect(polls).to eq ['Starting', 'Printing from SD', 'Operational']
    end

    ['Operational', 'Offline', 'Offline after error', 'Error: Printer halted', 'Connecting'].each do |state|
      it "stops monitoring when the printer is #{state}" do
        octoprint_states('Printing', state, 'Printing')
        operation.execute
        expect(polls).to eq ['Printing', state]
      end
    end

    context 'when OctoPrint fails while the print is paused' do
      let(:paused) { Octoprint::Job.deserialize({ state: 'Paused', job: { file: {} }, progress: {} }) }
      let(:operational) { Octoprint::Job.deserialize({ state: 'Operational', job: { file: {} }, progress: {} }) }
      let(:timeout) { Octoprint::Exceptions::TimeoutError.new('Net::ReadTimeout') }

      it 'retries and keeps monitoring' do
        answers = [paused, timeout, JSON::ParserError.new('unexpected token'), paused, operational]
        allow(Octoprint::Job).to receive(:get) do
          answer = answers.shift
          answer.is_a?(Exception) ? raise(answer) : answer
        end

        expect { operation.execute }.not_to raise_error
        expect(Octoprint::Job).to have_received(:get).exactly(5).times
        expect(operation).to have_received(:log).with(/Could not read the print's state/).once # One streak
      end

      it 'gives up after MAX_POLL_FAILURES consecutive failures, without raising' do
        stub_const('Spooler::Print::MAX_POLL_FAILURES', 3)
        allow(Octoprint::Job).to receive(:get).and_raise(timeout)

        expect { operation.execute }.not_to raise_error
        expect(Octoprint::Job).to have_received(:get).exactly(3).times
        expect(operation).to have_received(:log).with(/Could not read the print's state/).once
        expect(operation).to have_received(:log).with(/Gave up monitoring the print after 3 failed polls/)
      end
    end

    it 'waits WAIT_TIME between polls, not after the last one' do
      octoprint_states('Printing', 'Paused', 'Operational')
      operation.execute
      expect(operation).to have_received(:sleep).with(Spooler::WAIT_TIME).twice
    end

    it 'tracks the progress only while printing' do
      octoprint_states('Printing', 'Paused', 'Cancelling', 'Operational', completion: 42.1)
      allow(operation).to receive(:track_progress).and_call_original

      operation.execute

      expect(operation).to have_received(:track_progress).with(43).once
      expect(operation).to have_received(:log).with('43%').once
      expect(printer_job.reload.progress).to eq 43
    end

    it 'notifies the subscribers of the progress' do
      octoprint_states('Printing', 'Printing', 'Operational')
      operation.execute
      # Before the upload, once per printing poll, and at the end
      expect(subscriptions).to have_received(:trigger).with(:printer_subscription, { id: printer.id }, {}).exactly(4)
    end

    it 'does not crash when OctoPrint has no completion yet' do
      octoprint_states('Starting', 'Operational', completion: nil)
      allow(operation).to receive(:track_progress)

      expect { operation.execute }.not_to raise_error
      expect(operation).not_to have_received(:track_progress)
    end

    it 'does not crash when OctoPrint has no progress at all' do
      allow(Octoprint::Job).to receive(:get).and_return(
        Octoprint::Job.deserialize({ state: 'Starting', job: {} }),
        Octoprint::Job.deserialize({ state: 'Operational', job: {} })
      )
      expect { operation.execute }.not_to raise_error
    end

    it "uses the printer's own client without touching the global configuration" do
      allow(Octoprint).to receive(:configure)
      client_before = Octoprint.client
      clients = []
      jobs = %w[Printing Operational].map { |state| Octoprint::Job.deserialize({ state:, job: {} }) }
      allow(Octoprint::Job).to receive(:get) { clients << Octoprint.client and jobs.shift }

      operation.execute

      expect(clients).to eq [printer.api.client, printer.api.client]
      expect(clients.first).to have_attributes(host: printer.uri, api_key: printer.secret)
      expect(Octoprint).not_to have_received(:configure)
      expect(Octoprint.client).to be client_before
    end
  end
end
