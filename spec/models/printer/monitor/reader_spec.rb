# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Monitor::Reader do
  describe '.for' do
    it 'returns an OctoprintReader for an OctoPrint printer' do
      printer = build(:printer, backend: 'octoprint')
      expect(described_class.for(printer)).to be_a(Printer::Monitor::OctoprintReader).and have_attributes(printer:)
    end

    it 'returns a PrusalinkReader for a PrusaLink printer' do
      printer = build(:printer, :prusalink)
      expect(described_class.for(printer)).to be_a(Printer::Monitor::PrusalinkReader).and have_attributes(printer:)
    end

    it 'raises for an unknown backend' do
      printer = build(:printer, backend: 'repetier')
      expect { described_class.for(printer) }.to raise_error(ArgumentError, 'Unknown printer backend "repetier"')
    end
  end
end
