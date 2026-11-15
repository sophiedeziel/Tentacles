# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterBackends do
  describe '.for' do
    it 'returns the OctoPrint adapter of an OctoPrint printer' do
      printer = build(:printer, backend: 'octoprint')
      expect(described_class.for(printer)).to be_a(PrinterBackends::Octoprint).and have_attributes(printer:)
    end

    it 'returns the PrusaLink adapter of a PrusaLink printer' do
      printer = build(:printer, :prusalink)
      expect(described_class.for(printer)).to be_a(PrinterBackends::Prusalink).and have_attributes(printer:)
    end

    it 'raises for an unknown backend' do
      printer = build(:printer, backend: 'repetier')
      expect { described_class.for(printer) }.to raise_error(ArgumentError, 'Unknown printer backend "repetier"')
    end
  end

  it 'has a single base for the errors the callers rescue' do
    expect([PrinterBackends::Unreachable, PrinterBackends::Unauthorized, PrinterBackends::MissingCredentials,
            PrinterBackends::NoJob])
      .to all(be < PrinterBackends::Error)
  end
end
