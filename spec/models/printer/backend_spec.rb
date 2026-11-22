# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Backend do
  describe '.for' do
    it 'returns the OctoPrint adapter of an OctoPrint printer' do
      printer = build(:printer, backend: 'octoprint')
      expect(described_class.for(printer)).to be_a(Printer::Backend::Octoprint).and have_attributes(printer:)
    end

    it 'returns the PrusaLink adapter of a PrusaLink printer' do
      printer = build(:printer, :prusalink)
      expect(described_class.for(printer)).to be_a(Printer::Backend::Prusalink).and have_attributes(printer:)
    end

    it 'raises for an unknown backend' do
      printer = build(:printer, backend: 'repetier')
      expect { described_class.for(printer) }.to raise_error(ArgumentError, 'Unknown printer backend "repetier"')
    end
  end

  it 'is abstract: only its adapters are built' do
    expect { described_class.new(printer: build(:printer)) }.to raise_error(/abstract/)
  end

  it 'has nothing to save' do
    expect { described_class.for(build(:printer)).save }.to raise_error(NotImplementedError)
  end

  it 'has a single base for the errors the callers rescue' do
    expect([Printer::Backend::Unreachable, Printer::Backend::Unauthorized, Printer::Backend::MissingCredentials,
            Printer::Backend::NoJob])
      .to all(be < Printer::Backend::Error)
  end
end
