# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::StateFamily do
  describe '.for' do
    # Every text OctoPrint 1.11.8's MachineCom#getStateString can return
    {
      'Offline' => described_class::Offline,
      'Opening serial connection' => described_class::Connecting,
      'Detecting serial connection' => described_class::Connecting,
      'Connecting' => described_class::Connecting,
      'Operational' => described_class::Operational,
      'Starting print from SD' => described_class::Printing,
      'Starting to send file to SD' => described_class::Printing,
      'Starting' => described_class::Printing,
      'Printing from SD' => described_class::Printing,
      'Sending file to SD' => described_class::Printing,
      'Printing' => described_class::Printing,
      'Cancelling' => described_class::Cancelling,
      'Pausing' => described_class::Paused,
      'Paused' => described_class::Paused,
      'Resuming' => described_class::Printing,
      'Finishing' => described_class::Printing,
      'Error' => described_class::Error,
      'Offline after error' => described_class::Error,
      'Transferring file to SD' => described_class::Printing,
      'Unknown State (16)' => described_class::Offline
    }.each do |state_text, family|
      it "maps OctoPrint 1.11's #{state_text.inspect} to #{family.serialize}" do
        allow(described_class).to receive(:log_unknown) # Unknown texts map to OFFLINE too: make sure it's a match

        expect(described_class.for(state_text)).to eq family
        expect(described_class).not_to have_received(:log_unknown)
      end
    end

    # Texts of older OctoPrint releases (1.3/1.4), the "Closed" connection state and our own unknown state text
    {
      'Opening serial port' => described_class::Connecting,
      'Detecting serial port' => described_class::Connecting,
      'Detecting baudrate' => described_class::Connecting,
      'Error: Printer halted' => described_class::Error,
      'Offline (Error: Too many consecutive timeouts)' => described_class::Error,
      'Closed' => described_class::Offline,
      Printer::Status::UNKNOWN_STATE_TEXT => described_class::Offline
    }.each do |state_text, family|
      it "maps the older #{state_text.inspect} to #{family.serialize}" do
        allow(described_class).to receive(:log_unknown) # Unknown texts map to OFFLINE too: make sure it's a match

        expect(described_class.for(state_text)).to eq family
        expect(described_class).not_to have_received(:log_unknown)
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

  describe '.for_prusalink' do
    # Every PrusaLink printer state, with and without a job
    [
      ['PRINTING', true, described_class::Printing],
      ['PAUSED', true, described_class::Paused],
      ['ATTENTION', true, described_class::Paused],
      ['ATTENTION', false, described_class::Error],
      ['IDLE', false, described_class::Operational],
      ['READY', false, described_class::Operational],
      ['FINISHED', true, described_class::Operational],
      ['FINISHED', false, described_class::Operational],
      ['STOPPED', true, described_class::Operational],
      ['STOPPED', false, described_class::Operational],
      ['BUSY', false, described_class::Operational],
      ['ERROR', false, described_class::Error],
      ['ERROR', true, described_class::Error]
    ].each do |state, job, family|
      it "maps #{state} #{job ? 'with' : 'without'} a job to #{family.serialize}" do
        allow(described_class).to receive(:log_unknown)

        expect(described_class.for_prusalink(state, job:)).to eq family
        expect(described_class).not_to have_received(:log_unknown)
      end
    end

    it 'maps nil and blank states to OFFLINE without logging' do
      expect(Rails.logger).not_to receive(:warn)

      expect(described_class.for_prusalink(nil, job: false)).to eq described_class::Offline
      expect(described_class.for_prusalink('', job: false)).to eq described_class::Offline
    end

    context 'with an unknown state' do
      let(:state) { "TRANSMOGRIFYING_#{SecureRandom.hex(4)}" }

      it 'maps it to OFFLINE' do
        expect(described_class.for_prusalink(state, job: false)).to eq described_class::Offline
      end

      it 'logs it once' do
        expect(Rails.logger).to receive(:warn).with(/Unknown PrusaLink state "#{state}"/).once

        2.times { described_class.for_prusalink(state, job: true) }
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

  describe '#in_progress?' do
    it 'is true while a print is under way (printing, paused or cancelling)' do
      in_progress = described_class.values.select(&:in_progress?)

      expect(in_progress).to contain_exactly(described_class::Printing, described_class::Paused,
                                             described_class::Cancelling)
    end

    it 'is true for a print that is pausing, resuming or finishing' do
      expect(%w[Pausing Resuming Finishing].map { |text| described_class.for(text).in_progress? }).to all(be true)
    end

    it 'is false once the print is over or the printer is gone' do
      states = ['Operational', 'Offline', 'Error', 'Offline after error', 'Connecting', 'Unknown State (16)']
      expect(states.map { |text| described_class.for(text).in_progress? }).to all(be false)
    end
  end
end
