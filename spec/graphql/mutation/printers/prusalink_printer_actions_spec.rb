# frozen_string_literal: true

require 'rails_helper'
require 'support/unreadable_secret'
require_relative 'printer_action_shared_examples'

# The printer action mutations with a PrusaLink printer. The prusalink gem is stubbed: Prusalink::Status.get answers
# with `prusalink_state` (and a job unless it's idle) and Prusalink::Job.get with job 42.
RSpec.describe 'Printer actions on a PrusaLink printer', type: :request do
  let(:prusalink_state) { 'PRINTING' }
  let(:prusalink_job) { { id: 42, progress: 12.0 } }

  before do
    allow(Prusalink::Status).to receive(:get) do
      Prusalink::Status.deserialize({ printer: { state: prusalink_state }, job: prusalink_job&.dup })
    end
    allow(Prusalink::Job).to receive(:get) { Prusalink::Job.deserialize({ id: 42, state: prusalink_state }) }
    %i[pause resume stop].each { |method| allow(Prusalink::Job).to receive(method).and_return(true) }
  end

  def expect_failure(message)
    expect(json['errors']).to be_nil
    expect(result).to eq('success' => false, 'errors' => [message], 'printer' => returned_printer)
    expect(Printer::Status).not_to have_received(:find_or_initialize_by)
  end

  def expect_no_command
    %i[pause resume stop].each { |method| expect(Prusalink::Job).not_to have_received(method) }
  end

  {
    'pausePrint' => { command: :pause, allowed: 'PRINTING', refused: 'Prusa MK4 is no longer printing' },
    'resumePrint' => { command: :resume, allowed: 'PAUSED', refused: 'Prusa MK4 is no longer paused' },
    'cancelPrint' => { command: :stop, allowed: 'PRINTING', refused: 'Prusa MK4 is no longer printing' }
  }.each do |mutation, options|
    command, allowed, refused = options.values_at(:command, :allowed, :refused)

    describe mutation do
      include_context 'with a printer action request', mutation

      let(:printer) { create(:printer, :prusalink, name: 'Prusa MK4') }

      context "when PrusaLink is #{allowed} during a job" do
        let(:prusalink_state) { allowed }

        before { run_mutation }

        it "sends #{command} with the id of the current job" do
          expect(Prusalink::Job).to have_received(command).once.with(42)
        end

        it 'succeeds and refreshes the printer status' do
          expect(json['errors']).to be_nil
          expect(result).to eq('success' => true, 'errors' => [], 'printer' => returned_printer)
          expect(Printer::Status).to have_received(:find_or_initialize_by).once.with(printer:)
          expect(refreshed_status).to have_received(:reload).once
        end
      end

      context 'when PrusaLink is IDLE' do
        let(:prusalink_state) { 'IDLE' }

        before { run_mutation }

        it 'refuses without sending anything' do
          expect_failure(refused)
          expect_no_command
        end
      end

      # The screen confirms the file the monitor showed: the display name, as PrusaLink names the job's file
      context 'when the user confirmed a file' do
        let(:prusalink_state) { allowed }
        let(:job_file) { { name: 'BRACKE~1.BGC', display_name: 'bracket_v3.bgcode' } }

        before do
          allow(Prusalink::Job).to receive(:get) do
            Prusalink::Job.deserialize({ id: 42, state: prusalink_state, file: job_file })
          end
        end

        def run_confirmed(file_name)
          input = { printerId: printer.id.to_s, expectedFileName: file_name }
          post '/graphql', params: { query:, variables: { input: } }
        end

        it "sends #{command} to the job it checked, read once" do
          run_confirmed('bracket_v3.bgcode')
          expect(result).to eq('success' => true, 'errors' => [], 'printer' => returned_printer)
          expect(Prusalink::Job).to have_received(command).once.with(42)
          expect(Prusalink::Job).to have_received(:get).once
        end
      end

      context 'when PrusaLink is unreachable' do
        before do
          allow(Prusalink::Status).to receive(:get)
            .and_raise(Prusalink::Exceptions::ConnectionError, 'Failed to open TCP connection to prusa-mk4.local:80')
          run_mutation
        end

        it 'names PrusaLink in the error' do
          expect_failure("Could not reach Prusa MK4's PrusaLink: Failed to open TCP connection to prusa-mk4.local:80")
          expect_no_command
        end
      end

      context 'when an error message contains the password' do
        before do
          allow(Prusalink::Status).to receive(:get)
            .and_raise(Prusalink::Exceptions::ConnectionError, 'Failed with printer-password')
          run_mutation
        end

        it { expect_failure("Could not reach Prusa MK4's PrusaLink: Failed with [FILTERED]") }
      end

      context 'when the stored password cannot be decrypted' do
        include UnreadableSecret

        let(:printer) { make_secret_unreadable(create(:printer, :prusalink, name: 'Prusa MK4')) }

        before { run_mutation }

        it 'returns the error without calling PrusaLink' do
          expect_failure("Prusa MK4's stored PrusaLink password can't be read, re-enter it")
          expect(Prusalink::Status).not_to have_received(:get)
        end
      end
    end
  end

  %w[connectPrinter reconnectPrinter].each do |mutation|
    describe mutation do
      include_context 'with a printer action request', mutation

      let(:printer) { create(:printer, :prusalink, name: 'Prusa MK4') }

      context 'when PrusaLink is IDLE' do
        let(:prusalink_state) { 'IDLE' }
        let(:prusalink_job) { nil }

        before { run_mutation }

        it 'refuses without contacting the printer' do
          expect_failure('PrusaLink printers connect on their own')
          expect(Prusalink::Status).not_to have_received(:get)
        end
      end
    end
  end
end
