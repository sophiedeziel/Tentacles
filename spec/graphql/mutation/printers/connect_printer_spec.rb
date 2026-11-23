# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

RSpec.describe Mutations::Printers::ConnectPrinter, type: :request do
  it_behaves_like 'a printer action',
                  mutation: 'connectPrinter',
                  commands: [[Octoprint::Connection, :connect]],
                  allowed: [Printer::StateFamily::Offline],
                  refusals: { Printer::StateFamily::Printing => 'Prusa MK4 is already connected' }

  describe 'connection parameters' do
    include_context 'with a printer action request', 'connectPrinter'

    let(:job_state) { 'Offline' }

    it 'autodetects the port and baudrate, uses the default profile and leaves the saved preferences alone' do
      sent = []
      allow(Octoprint::Connection).to receive(:post) { |params:| sent << params and true }

      2.times { run_mutation }

      expect(sent).to eq([{ port: 'AUTO', baudrate: 0, command: 'connect' }] * 2)
    end
  end
end
