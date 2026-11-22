# frozen_string_literal: true

require 'rails_helper'
require_relative 'command_shared_examples'

RSpec.describe Printer::Connection do
  it_behaves_like 'a printer command',
                  sends: :connect,
                  allowed: [Printer::StateFamily::Offline],
                  refusals: {
                    Printer::StateFamily::Printing => 'Prusa MK4 is already connected',
                    Printer::StateFamily::Paused => 'Prusa MK4 is already connected',
                    Printer::StateFamily::Cancelling => 'Prusa MK4 is already connected',
                    Printer::StateFamily::Operational => 'Prusa MK4 is already connected',
                    Printer::StateFamily::Connecting => 'Prusa MK4 is already connecting',
                    Printer::StateFamily::Error => 'Prusa MK4 is in error, reconnect it instead'
                  }

  it_behaves_like 'a connection command', sends: :connect
end
