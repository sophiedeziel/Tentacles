# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::FilamentChange do
  let(:subscriptions) { TentaclesSchema.subscriptions }
  let(:printer) { create(:printer) }

  before { allow(subscriptions).to receive(:trigger) }

  def build_change(**attributes)
    described_class.new(printer:, material: 'PLA', colour: 'Black', **attributes)
  end

  it 'sets the filament of a printer that has none in one row, in slot 1' do
    expect { build_change.save! }.to change(Printer::LoadedFilament, :count).by(1)

    expect(printer.loaded_filaments.sole).to have_attributes(slot: 1, material: 'PLA', colour: 'Black')
  end

  it 'replaces the filament when set again, leaving one row' do
    build_change.save!

    replace = build_change(material: 'PETG', colour: 'Galaxy Grey')

    expect { replace.save! }.not_to change(Printer::LoadedFilament, :count)

    expect(printer.loaded_filaments.sole).to have_attributes(material: 'PETG', colour: 'Galaxy Grey',
                                                             colour_key: 'galaxy grey')
  end

  it 'gives the saved filament' do
    filament_change = build_change(material: ' petg ', colour: ' Galaxy Grey ')
    filament_change.save!

    expect(filament_change.loaded_filament).to be_persisted
    expect(filament_change.loaded_filament.reload).to have_attributes(material: 'PETG', colour: 'Galaxy Grey')
  end

  it 'allows a material the printer specs do not list' do
    printer.update!(materials: ['PLA'])

    expect(build_change(material: 'TPU').save).to be true
  end

  it 'turns filament_set? true, on a printer whose filaments were read before' do
    expect(printer.loaded_filaments.load).to be_empty

    build_change.save!

    expect(printer.filament_set?).to be true
  end

  it 'leaves the filament of the other slots and printers alone' do
    printer.update!(filament_slots: 2)
    create(:printer_loaded_filament, printer:, slot: 2, material: 'ABS', colour: 'Red')
    other = create(:printer_loaded_filament, material: 'ASA', colour: 'White')

    build_change(material: 'PETG').save!

    expect(printer.loaded_filaments.order(:slot).pluck(:slot, :material)).to eq [[1, 'PETG'], [2, 'ABS']]
    expect(other.reload.material).to eq 'ASA'
  end

  it 'pushes printerStatusChanged once, with the printer' do
    build_change.save!

    expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
  end

  it 'pushes the printer with its new filament, even when it had read them before' do
    printer.loaded_filaments.load
    pushed = nil
    allow(subscriptions).to receive(:trigger) { |_event, _args, object| pushed = object.loaded_filaments.map(&:colour) }

    build_change(colour: 'Galaxy Grey').save!

    expect(pushed).to eq ['Galaxy Grey']
  end

  context 'when the push fails' do
    before do
      allow(subscriptions).to receive(:trigger).and_raise(Redis::CannotConnectError, 'Redis is down')
      allow(Rails.logger).to receive(:error)
    end

    it 'keeps the filament, succeeds and logs the failure' do
      expect(build_change.save).to be true

      expect(printer.loaded_filaments.count).to eq 1
      expect(Rails.logger).to have_received(:error).with(/Could not push printerStatusChanged.*Redis is down/)
    end
  end

  describe 'refused filaments' do
    {
      'a material outside the list' => [{ material: 'Wood' }, :material, ['Material is not included in the list']],
      'a blank colour' => [{ colour: ' ' }, :colour, ["Colour can't be blank"]],
      'a colour over 40 characters' => [{ colour: 'x' * 41 }, :colour,
                                        ['Colour is too long (maximum is 40 characters)']],
      "a slot above the printer's" => [{ slot: 2 }, :slot, ['Slot must be less than or equal to 1']],
      'no slot' => [{ slot: nil }, :slot, ['Slot is not a number']]
    }.each do |refused, (attributes, attribute, messages)|
      context "with #{refused}" do
        let(:filament_change) { build_change(**attributes) }

        it "returns false with the error under #{attribute}, changing nothing" do
          expect(filament_change.save).to be false

          expect(filament_change.errors[attribute]).to be_present
          expect(filament_change.errors.full_messages).to eq messages
          expect(Printer::LoadedFilament.count).to eq 0
          expect(subscriptions).not_to have_received(:trigger)
        end
      end
    end

    it 'keeps the filament in place when replacing it is refused' do
      build_change.save!

      expect(build_change(material: 'Wood').save).to be false

      expect(printer.loaded_filaments.sole.material).to eq 'PLA'
    end

    it 'leaves filament_set? false, on a printer whose filaments were read before' do
      printer.loaded_filaments.load

      build_change(colour: '').save

      expect(printer.filament_set?).to be false
    end

    it 'raises from save!' do
      expect { build_change(material: 'Wood').save! }.to raise_error(ActiveModel::ValidationError)
    end

    it 'is invalid without a printer' do
      filament_change = described_class.new(material: 'PLA', colour: 'Black')

      expect(filament_change.save).to be false
      expect(filament_change.errors.full_messages).to eq ["Printer can't be blank"]
    end
  end

  context 'when someone else sets the slot at the same time' do
    # The other save lands between this change's validation and its insert: the unique index refuses the insert
    before do
      allow(Printer::LoadedFilament).to receive(:find_or_initialize_by).and_wrap_original do |original, **attributes|
        original.call(**attributes).tap do |filament|
          allow(filament).to receive(:save!) do
            create(:printer_loaded_filament, printer:, material: 'PETG', colour: 'Grey')
            raise ActiveRecord::RecordNotUnique
          end
        end
      end
    end

    it 'updates the row that won, leaving one row with its own values' do
      filament_change = build_change(material: 'ABS', colour: 'Red')

      expect(filament_change.save).to be true

      expect(printer.loaded_filaments.sole).to have_attributes(material: 'ABS', colour: 'Red')
      expect(filament_change.loaded_filament).to eq printer.loaded_filaments.sole
      expect(subscriptions).to have_received(:trigger).with(:printer_status_changed, {}, printer).once
    end
  end
end
