# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::FilamentRemoval do
  let(:subscriptions) { TentaclesSchema.subscriptions }
  let(:printer) { create(:printer) }

  before { allow(subscriptions).to receive(:trigger) }

  context 'when the slot has a filament' do
    before { create(:printer_loaded_filament, printer:) }

    it 'removes it, and filament_set? turns false' do
      expect(printer.filament_set?).to be true

      removal = described_class.new(printer:)
      removal.save!

      expect(removal).to be_removed
      expect(Printer::LoadedFilament.where(printer:)).to be_empty
      expect(printer.filament_set?).to be false
    end

    it 'pushes printerStatusChanged once, with the printer' do
      described_class.new(printer:).save!

      expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
    end

    it 'keeps the removal, succeeds and logs the failure when the push fails' do
      allow(subscriptions).to receive(:trigger).and_raise(StandardError, 'ActionCable is down')
      allow(Rails.logger).to receive(:error)

      expect(described_class.new(printer:).save).to be true

      expect(printer.loaded_filaments.reload).to be_empty
      expect(Rails.logger).to have_received(:error).with(/Could not push printerStatusChanged.*ActionCable is down/)
    end
  end

  describe 'the global queue' do
    before do
      create(:printer_loaded_filament, printer:)
      allow(PrintQueue).to receive(:push_changed)
      allow(PrintQueue::DispatchRequest).to receive(:new)
    end

    it 'pushes the printer queue change once the filament is removed, and asks for no dispatch pass' do
      allow(PrintQueue).to receive(:enabled?).and_return(true)
      allow(PrintQueue).to receive(:push_changed) { expect(printer.loaded_filaments.count).to eq 0 }

      described_class.new(printer:).save!

      expect(PrintQueue).to have_received(:push_changed).once.with([printer])
      expect(PrintQueue::DispatchRequest).not_to have_received(:new)
    end

    it 'pushes nothing while the global queue is off' do
      allow(PrintQueue).to receive(:enabled?).and_return(false)

      described_class.new(printer:).save!

      expect(PrintQueue).not_to have_received(:push_changed)
    end

    it 'pushes nothing when the slot had no filament' do
      allow(PrintQueue).to receive(:enabled?).and_return(true)

      described_class.new(printer:, slot: 2).save!

      expect(PrintQueue).not_to have_received(:push_changed)
    end
  end

  it 'leaves the other slots and printers alone' do
    printer.update!(filament_slots: 2)
    create(:printer_loaded_filament, printer:, slot: 1)
    create(:printer_loaded_filament, printer:, slot: 2)
    other = create(:printer_loaded_filament)

    described_class.new(printer:, slot: 2).save!

    expect(printer.loaded_filaments.pluck(:slot)).to eq [1]
    expect(other.reload).to be_persisted
  end

  context 'when the slot has no filament' do
    it 'succeeds, changing and pushing nothing' do
      create(:printer_loaded_filament) # Another printer's

      removal = described_class.new(printer:)

      expect { expect(removal.save).to be true }.not_to change(Printer::LoadedFilament, :count)
      expect(removal).not_to be_removed
      expect(subscriptions).not_to have_received(:trigger)
    end
  end

  it 'is invalid without a printer' do
    removal = described_class.new

    expect(removal.save).to be false
    expect(removal.errors.full_messages).to eq ["Printer can't be blank"]
  end
end
