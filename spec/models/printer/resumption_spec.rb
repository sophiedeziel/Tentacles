# frozen_string_literal: true

require 'rails_helper'
require_relative 'command_shared_examples'

RSpec.describe Printer::Resumption do
  it_behaves_like 'a printer command',
                  sends: :resume,
                  allowed: [Printer::StateFamily::Paused],
                  refusals: {
                    Printer::StateFamily::Printing => 'Prusa MK4 is no longer paused',
                    Printer::StateFamily::Cancelling => 'Prusa MK4 is no longer paused',
                    Printer::StateFamily::Operational => 'Prusa MK4 is no longer paused',
                    Printer::StateFamily::Connecting => 'Prusa MK4 is no longer paused',
                    Printer::StateFamily::Error => 'Prusa MK4 is no longer paused',
                    Printer::StateFamily::Offline => 'Prusa MK4 is no longer paused'
                  }

  it_behaves_like 'a job command', sends: :resume, state: Printer::StateFamily::Paused
end
