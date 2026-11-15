# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrinterStateFamily do
  describe '.for' do
    {
      'Starting' => described_class::Printing,
      'Printing' => described_class::Printing,
      'Printing from SD' => described_class::Printing,
      'Sending file to SD' => described_class::Printing,
      'Resuming' => described_class::Printing,
      'Finishing' => described_class::Printing,
      'Pausing' => described_class::Paused,
      'Paused' => described_class::Paused,
      'Cancelling' => described_class::Cancelling,
      'Operational' => described_class::Operational,
      'Opening serial connection' => described_class::Connecting,
      'Detecting serial connection' => described_class::Connecting,
      'Connecting' => described_class::Connecting,
      'Error' => described_class::Error,
      'Offline after error' => described_class::Error,
      'Offline' => described_class::Offline,
      'Unknown' => described_class::Offline
    }.each do |state_text, family|
      it "maps #{state_text.inspect} to #{family.serialize}" do
        expect(described_class.for(state_text)).to eq family
      end
    end

    it 'matches by prefix' do
      expect(described_class.for('Error: Printer halted. kill() called!')).to eq described_class::Error
      expect(described_class.for('Starting print from SD')).to eq described_class::Printing
    end

    it 'ignores case and surrounding whitespace' do
      expect(described_class.for('  printing  ')).to eq described_class::Printing
    end

    it 'maps nil and blank text to OFFLINE without logging' do
      expect(Rails.logger).not_to receive(:warn)

      expect(described_class.for(nil)).to eq described_class::Offline
      expect(described_class.for('')).to eq described_class::Offline
    end

    context 'with an unknown state text' do
      let(:state_text) { "Transmogrifying #{SecureRandom.hex(4)}" }

      it 'maps it to OFFLINE' do
        expect(described_class.for(state_text)).to eq described_class::Offline
      end

      it 'logs it once' do
        expect(Rails.logger).to receive(:warn).with(/Unknown OctoPrint state "#{state_text}"/).once

        2.times { described_class.for(state_text) }
      end
    end
  end

  describe '#connected?' do
    it 'is true when OctoPrint is connected to the printer' do
      connected = described_class.values.select(&:connected?)

      expect(connected).to contain_exactly(described_class::Printing, described_class::Paused,
                                           described_class::Cancelling, described_class::Operational)
    end
  end
end
