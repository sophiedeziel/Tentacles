# frozen_string_literal: true

require 'rails_helper'
require_relative 'command_shared_examples'

RSpec.describe Printer::Pause do
  it_behaves_like 'a printer command',
                  sends: :pause,
                  allowed: [Printer::StateFamily::Printing],
                  refusals: {
                    Printer::StateFamily::Paused => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Cancelling => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Operational => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Connecting => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Error => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Offline => 'Prusa MK4 is no longer printing'
                  }

  it_behaves_like 'a job command', sends: :pause, state: Printer::StateFamily::Printing
end
