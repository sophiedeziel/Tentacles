# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterMonitor::Reader do
  describe '.for' do
    it 'returns an OctoprintReader for an OctoPrint printer' do
      printer = build(:printer, backend: 'octoprint')
      expect(described_class.for(printer)).to be_a(PrinterMonitor::OctoprintReader).and have_attributes(printer:)
    end

    it 'raises for an unknown backend' do
      printer = build(:printer, backend: 'repetier')
      expect { described_class.for(printer) }.to raise_error(ArgumentError, 'Unknown printer backend "repetier"')
    end
  end
end
