# frozen_string_literal: true

require 'rails_helper'
require_relative 'printer_action_shared_examples'

RSpec.describe Mutations::Printers::ResumePrint, type: :request do
  it_behaves_like 'a printer action',
                  mutation: 'resumePrint',
                  commands: [[Octoprint::Job, :resume]],
                  allowed: [Printer::StateFamily::Paused],
                  refusals: { Printer::StateFamily::Printing => 'Prusa MK4 is no longer paused' }
end
