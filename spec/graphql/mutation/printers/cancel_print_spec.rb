# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

RSpec.describe Mutations::Printers::CancelPrint, type: :request do
  it_behaves_like 'a printer action',
                  mutation: 'cancelPrint',
                  commands: [[Octoprint::Job, :cancel]],
                  allowed: [PrinterStateFamily::Printing, PrinterStateFamily::Paused],
                  refusals: {
                    PrinterStateFamily::Cancelling => 'Prusa MK4 is no longer printing',
                    PrinterStateFamily::Operational => 'Prusa MK4 is no longer printing',
                    PrinterStateFamily::Connecting => 'Prusa MK4 is no longer printing',
                    PrinterStateFamily::Error => 'Prusa MK4 is no longer printing',
                    PrinterStateFamily::Offline => 'Prusa MK4 is no longer printing'
                  }
end
