# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

# A stale screen must not act on another print than the one the user confirmed
RSpec.describe 'Printer actions with the job the user confirmed', type: :request do
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }
  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:json) { response.parsed_body }
  let(:refreshed_status) { instance_spy(Printer::Status) }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(Printer::Status).to receive(:find_or_initialize_by).and_return(refreshed_status)
  end

  def octoprint_job(state, file_name)
    allow(Octoprint::Job).to receive(:get) do
      Octoprint::Job.deserialize({ state:, job: file_name ? { file: { name: file_name } } : {} })
    end
  end

  def run(mutation, **input)
    query = "mutation($input: #{mutation.upcase_first}Input!) { #{mutation}(input: $input) { success errors } }"
    post '/graphql', params: { query:, variables: { input: { printerId: printer.id.to_s, **input } } }
    json['data'][mutation]
  end

  {
    'pausePrint' => ['Printing', [Octoprint::Job, :pause]],
    'resumePrint' => ['Paused', [Octoprint::Job, :resume]],
    'cancelPrint' => ['Printing', [Octoprint::Job, :cancel]]
  }.each do |mutation, (state, (receiver, command))|
    describe mutation do
      before { allow(receiver).to receive(command).and_return(true) }

      it 'acts when the printer is printing the confirmed file' do
        octoprint_job(state, 'bracket_v3.gcode')
        expect(run(mutation, expectedFileName: 'bracket_v3.gcode')).to eq('success' => true, 'errors' => [])
        expect(receiver).to have_received(command).once
      end

      it 'refuses when the printer is printing another file' do
        octoprint_job(state, 'gear_v2.gcode')
        expect(run(mutation, expectedFileName: 'bracket_v3.gcode'))
          .to eq('success' => false, 'errors' => ['Prusa MK4 is now printing gear_v2.gcode'])
        expect(receiver).not_to have_received(command)
      end

      it 'refuses when OctoPrint reports no file' do
        octoprint_job(state, nil)
        expect(run(mutation, expectedFileName: 'bracket_v3.gcode'))
          .to eq('success' => false, 'errors' => ['Prusa MK4 is no longer printing bracket_v3.gcode'])
        expect(receiver).not_to have_received(command)
      end

      it 'refuses for the state first' do
        octoprint_job('Operational', nil)
        expect(run(mutation, expectedFileName: 'bracket_v3.gcode')['errors'].first).not_to include('bracket_v3.gcode')
        expect(receiver).not_to have_received(command)
      end

      it 'does not check the file when none is given' do
        octoprint_job(state, 'gear_v2.gcode')
        expect(run(mutation)).to eq('success' => true, 'errors' => [])
      end
    end
  end

  describe 'startNextPrint' do
    let!(:first) { create(:printer_job, printer:, status: 'enqueued', created_at: 1.hour.ago) }

    before do
      octoprint_job('Operational', nil)
      allow(redis).to receive(:publish)
    end

    it 'starts the queue when its next job is the confirmed one' do
      create(:printer_job, printer:, status: 'enqueued')
      expect(run('startNextPrint', expectedJobId: first.id.to_s)).to eq('success' => true, 'errors' => [])
      expect(redis).to have_received(:publish).once
    end

    it 'refuses when another job is now first' do
      other = create(:printer_job, printer:, status: 'enqueued', created_at: 2.hours.ago)
      other.executable.file.blob.update!(filename: 'gear_v2.gcode')

      expect(run('startNextPrint', expectedJobId: first.id.to_s))
        .to eq('success' => false, 'errors' => ["Prusa MK4's next job is now gear_v2.gcode"])
      expect(redis).not_to have_received(:publish)
    end

    it 'does not check the job when none is given' do
      expect(run('startNextPrint')).to eq('success' => true, 'errors' => [])
    end
  end
end
