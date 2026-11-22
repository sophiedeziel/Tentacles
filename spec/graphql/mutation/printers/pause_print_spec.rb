# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

RSpec.describe Mutations::Printers::PausePrint, type: :request do
  it_behaves_like 'a printer action',
                  mutation: 'pausePrint',
                  commands: [[Octoprint::Job, :pause]],
                  allowed: [Printer::StateFamily::Printing],
                  refusals: {
                    Printer::StateFamily::Paused => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Cancelling => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Operational => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Connecting => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Error => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Offline => 'Prusa MK4 is no longer printing'
                  }

  describe 'the inline monitor tick' do
    include_context 'with a printer action request', 'pausePrint'

    before do
      allow(Printer::Status).to receive(:find_or_initialize_by).and_call_original
      allow(TentaclesSchema.subscriptions).to receive(:trigger)
      states = %w[Printing Pausing]
      allow(Octoprint::Job).to receive(:get) { Octoprint::Job.deserialize({ state: states.shift || 'Paused', job: {} }) }
      allow(Octoprint::Job).to receive(:pause).and_return(true)
      allow(Octoprint::Printer).to receive(:get) do
        Octoprint::Printer.deserialize({ temperature: { tool0: { actual: 210.0, target: 210.0 } } })
      end
    end

    it 'pushes the new state before the response returns' do
      run_mutation

      expect(result['success']).to be true
      expect(Printer::Status.find_by(printer_id: printer.id)).to have_attributes(state_family: Printer::StateFamily::Paused,
                                                                                 state_text: 'Pausing')
      expect(TentaclesSchema.subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
    end
  end
end
