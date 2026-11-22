# frozen_string_literal: true

require 'rails_helper'
require_relative 'command_shared_examples'

RSpec.describe Printer::Cancellation do
  it_behaves_like 'a printer command',
                  sends: :cancel,
                  allowed: [Printer::StateFamily::Printing, Printer::StateFamily::Paused],
                  refusals: {
                    Printer::StateFamily::Cancelling => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Operational => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Connecting => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Error => 'Prusa MK4 is no longer printing',
                    Printer::StateFamily::Offline => 'Prusa MK4 is no longer printing'
                  }

  it_behaves_like 'a job command', sends: :cancel, state: Printer::StateFamily::Printing
  it_behaves_like 'a job command', sends: :cancel, state: Printer::StateFamily::Paused
end
