# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

RSpec.describe Mutations::Printers::StartNextPrint, type: :request do
  include_context 'with a printer action request', 'startNextPrint'

  # MockRedis doesn't implement PUBLISH
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }

  let(:start_print_message) { { command: :start_print, printer_id: printer.id }.to_json }

  before do
    allow(redis).to receive(:publish)
    create(:printer_job, printer:, status: 'enqueued')
  end

  def expect_refusal(message)
    expect(result).to eq('success' => false, 'errors' => [message], 'printer' => returned_printer)
    expect(redis).not_to have_received(:publish)
  end

  context 'when the printer is OPERATIONAL, with a queue and no active job' do
    before { run_mutation }

    it 'asks the spooler to start the next print' do
      expect(redis).to have_received(:publish).with('printers', start_print_message).once
    end

    it 'succeeds and returns the printer' do
      expect(json['errors']).to be_nil
      expect(result).to eq('success' => true, 'errors' => [], 'printer' => returned_printer)
    end

    it 'checks the live state' do
      expect(Octoprint::Job).to have_received(:get).once
    end

    it 'leaves the status refresh to the spooler' do
      expect(PrinterMonitor).not_to have_received(:refresh)
    end
  end

  it 'still works with the Queue section query, which only selects success' do
    query = Rails.root.join('app/ui/Sections/Printers/Queue/graphql/StartNextPrint.graphql').read
    post '/graphql', params: { query:, variables: { input: { printerId: printer.id.to_s } } }

    expect(json).to eq('data' => { 'startNextPrint' => { 'success' => true } })
  end

  (PRINTER_ACTION_STATES.keys - [PrinterStateFamily::Operational]).each do |family|
    context "when the printer is #{family.serialize}" do
      let(:job_state) { PRINTER_ACTION_STATES.fetch(family) }

      before { run_mutation }

      it { expect_refusal('Prusa MK4 is not ready to print') }
    end
  end

  context 'when the queue is empty' do
    before do
      printer.jobs.update_all(status: 'completed') # rubocop:disable Rails/SkipsModelValidations
      create(:printer_job, printer:, status: 'error')
      create(:printer_job, status: 'enqueued') # another printer's
      run_mutation
    end

    it { expect_refusal('Prusa MK4 has nothing in its queue') }
  end

  context 'when the printer already has an active job' do
    before do
      create(:printer_job, printer:, status: 'active')
      run_mutation
    end

    it { expect_refusal('Prusa MK4 already has an active job') }
  end

  it_behaves_like 'a printer action that fails gracefully', commands: []

  context 'when Redis is down' do
    before do
      allow(redis).to receive(:publish).and_raise(Redis::CannotConnectError)
      run_mutation
    end

    it { expect(result['errors']).to eq ["Could not ask the spooler to start Prusa MK4's next print"] }
    it { expect(result['success']).to be false }
  end
end
