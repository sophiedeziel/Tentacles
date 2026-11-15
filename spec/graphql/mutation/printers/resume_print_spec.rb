# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

RSpec.describe Mutations::Printers::ResumePrint, type: :request do
  it_behaves_like 'a printer action',
                  mutation: 'resumePrint',
                  commands: [[Octoprint::Job, :resume]],
                  allowed: [PrinterStateFamily::Paused],
                  refusals: {
                    PrinterStateFamily::Printing => 'Prusa MK4 is no longer paused',
                    PrinterStateFamily::Cancelling => 'Prusa MK4 is no longer paused',
                    PrinterStateFamily::Operational => 'Prusa MK4 is no longer paused',
                    PrinterStateFamily::Connecting => 'Prusa MK4 is no longer paused',
                    PrinterStateFamily::Error => 'Prusa MK4 is no longer paused',
                    PrinterStateFamily::Offline => 'Prusa MK4 is no longer paused'
                  }
end
