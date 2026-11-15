# frozen_string_literal: true

require 'rails_helper'
require 'spooler'

RSpec.describe Spooler::Spool do
  let(:printer) { create(:printer) }
  let(:spool) { described_class.new(printer) }

  # Spool.new starts its operations thread right away: it only spins while the spool isn't active
  after { spool.instance_variable_get(:@thread).kill.join }

  describe '#working?' do
    subject { spool.working? }

    it { is_expected.to eq false }
  end

  describe 'running a print job' do
    let(:printer_job) { create(:printer_job, printer:) }
    let(:operation) { Spooler::Print.new(printer, printer_job) }
    let(:job_status_at_each_poll) { [] }

    before do
      allow(TentaclesSchema).to receive(:subscriptions)
        .and_return(instance_double(GraphQL::Subscriptions, trigger: nil))
      allow(UploadFilesToPrintersJob).to receive(:perform_now)
      allow(operation).to receive(:sleep)
      allow(operation).to receive(:log)

      states = %w[Printing Paused Paused Printing Operational]
      allow(Octoprint::Job).to receive(:get) do
        state = states.shift
        job_status_at_each_poll << [state, printer_job.reload.status]
        Octoprint::Job.deserialize({ state:, job: { file: { name: 'cube.gcode' } }, progress: { completion: 50.0 } })
      end

      # What the operations loop does with the next job
      spool.instance_variable_set(:@current_operation, operation)
      spool.send(:start_and_monitor)
      spool.instance_variable_set(:@current_operation, nil)
    end

    it 'keeps the job active through a pause and a resume, until the print finishes' do
      expect(job_status_at_each_poll).to eq [
        %w[Printing active], %w[Paused active], %w[Paused active], %w[Printing active], %w[Operational active]
      ]
    end

    it 'completes the job once the print is over' do
      expect(printer_job.reload.status).to eq 'completed'
    end
  end
end
