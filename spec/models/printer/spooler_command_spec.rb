# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::SpoolerCommand do
  it 'serializes to the command names of the printers channel' do
    expect(described_class.values.map(&:serialize)).to eq %w[add_printer remove_printer start_print stop_print resume]
  end
end
