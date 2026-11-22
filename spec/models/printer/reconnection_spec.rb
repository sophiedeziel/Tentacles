# frozen_string_literal: true

require 'rails_helper'
require_relative 'command_shared_examples'

RSpec.describe Printer::Reconnection do
  it_behaves_like 'a printer command',
                  sends: :reconnect,
                  allowed: [Printer::StateFamily::Error],
                  refusals: {
                    Printer::StateFamily::Printing => 'Prusa MK4 is no longer in error',
                    Printer::StateFamily::Paused => 'Prusa MK4 is no longer in error',
                    Printer::StateFamily::Cancelling => 'Prusa MK4 is no longer in error',
                    Printer::StateFamily::Operational => 'Prusa MK4 is no longer in error',
                    Printer::StateFamily::Connecting => 'Prusa MK4 is no longer in error',
                    Printer::StateFamily::Offline => 'Prusa MK4 is no longer in error'
                  }

  it_behaves_like 'a connection command', sends: :reconnect
end
