# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

RSpec.describe Mutations::Printers::CancelPrint, type: :request do
  it_behaves_like 'a printer action',
                  mutation: 'cancelPrint',
                  commands: [[Octoprint::Job, :cancel]],
                  allowed: [Printer::StateFamily::Printing, Printer::StateFamily::Paused],
                  refusals: {
                    Printer::StateFamily::Cancelling => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Operational => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Connecting => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Error => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Offline => 'Prusa MK4 is no longer printing'
                  }
end
