# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

RSpec.describe Mutations::Printers::ReconnectPrinter, type: :request do
  it_behaves_like 'a printer action',
                  mutation: 'reconnectPrinter',
                  commands: [[Octoprint::Connection, :disconnect], [Octoprint::Connection, :connect]],
                  allowed: [Printer::StateFamily::Error],
                  refusals: { Printer::StateFamily::Printing => 'Prusa MK4 is no longer in error' }

  describe 'order of the commands' do
    include_context 'with a printer action request', 'reconnectPrinter'

    let(:job_state) { 'Error: Too many consecutive timeouts' }

    it 'does not connect when disconnecting fails' do
      allow(Octoprint::Connection).to receive(:disconnect).and_raise(Octoprint::Exceptions::InternalServerError,
                                                                     '[500] Oops')
      allow(Octoprint::Connection).to receive(:connect)

      run_mutation

      expect(result['errors']).to eq ["Prusa MK4's OctoPrint returned an error: [500] Oops"]
      expect(Octoprint::Connection).not_to have_received(:connect)
    end
  end
end
