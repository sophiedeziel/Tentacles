# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Fit do
  let(:printer) { build(:printer, build_volume_x: 250, build_volume_y: 210, build_volume_z: 220) }
  let(:operational) { status(Printer::StateFamily::Operational) }

  def status(family, state_text = family.serialize.capitalize, **attributes)
    Printer::Status.new(printer_id: 1, state_family: family, state_text:, **attributes)
  end

  # Needs of one tool per material (nil: Not known), and the entry's colour (nil: Any colour)
  def needs(materials: ['PLA'], colour: nil, **values)
    tools = materials.each_with_index.map { |material, tool| PrintQueue::Needs::Tool.new(tool:, material:) }
    PrintQueue::Needs.new(known: true, tools:, colour:, **values)
  end

  def load(material, colour, slot: 1)
    printer.loaded_filaments.build(slot:, material:, colour:)
  end

  def fit(needs, status: operational)
    described_class.new(needs:, printer:, status:)
  end

  def answer(fit) = [fit.result, fit.reasons.map(&:to_h)]

  describe 'precedence' do
    before { load('PETG', 'Black') }

    it 'cannot print with a hard limitation, whatever its state or filament' do
      result = fit(needs(width: 300, depth: 100), status: nil)

      expect(answer(result)).to eq [:cannot, [
        { code: :bed_too_small, message: 'Bed too small: needs 300 × 100 mm, has 250 × 210 mm' }
      ]]
      expect(result).to be_cannot
    end

    it 'is ready after a reconnect when offline, with the filament to change after the reason' do
      expect(answer(fit(needs, status: nil))).to eq [:after_reconnect, [
        { code: :offline, message: 'Offline' },
        { code: :wrong_material, message: 'Needs PLA. PETG is loaded here' }
      ]]
    end

    it 'is ready after a reconnect when offline, with only that reason when the filament matches' do
      expect(answer(fit(needs(materials: ['PETG']), status: nil))).to eq [:after_reconnect, [
        { code: :offline, message: 'Offline' }
      ]]
    end

    it 'is ready after a filament change when online with the wrong filament' do
      expect(answer(fit(needs))).to eq [:after_filament_change, [
        { code: :wrong_material, message: 'Needs PLA. PETG is loaded here' }
      ]]
    end

    it 'is ready, with what matched, otherwise' do
      result = fit(needs(materials: ['PETG']))

      expect(answer(result)).to eq [:ready, [{ code: :filament_matches, message: 'Loaded PETG Black matches' }]]
      expect(result).to be_ready
    end
  end

  describe '#filament_loaded?' do
    before { load('PLA', 'Black') }

    it 'is true when ready, or offline with nothing else in the way' do
      expect(fit(needs)).to be_filament_loaded
      expect(fit(needs, status: nil)).to be_filament_loaded
    end

    it 'is false when a filament change is needed, online or not, or when it cannot print' do
      expect(fit(needs(materials: ['PETG']))).not_to be_filament_loaded
      expect(fit(needs(materials: ['PETG']), status: nil)).not_to be_filament_loaded
      expect(fit(needs(width: 300, depth: 100))).not_to be_filament_loaded
    end
  end

  describe 'offline' do
    before { load('PLA', 'Black') }

    it 'is a printer without a snapshot' do
      expect(fit(needs, status: nil).reasons.first.to_h).to eq(code: :offline, message: 'Offline')
    end

    it 'is a printer Offline, Connecting or in Error, with its error' do
      {
        status(Printer::StateFamily::Offline) => 'Offline',
        status(Printer::StateFamily::Connecting) => 'Connecting',
        status(Printer::StateFamily::Error) => 'Error',
        status(Printer::StateFamily::Error, 'Error', error_text: 'Thermal runaway') => 'Error: Thermal runaway'
      }.each do |snapshot, message|
        expect(answer(fit(needs, status: snapshot))).to eq [:after_reconnect, [{ code: :offline, message: }]]
      end
    end

    it 'is not a printer that is printing, paused or cancelling: being busy is PrintQueue::Readiness' do
      [Printer::StateFamily::Printing, Printer::StateFamily::Paused, Printer::StateFamily::Cancelling].each do |family|
        expect(fit(needs, status: status(family))).to be_ready
      end
    end
  end

  describe 'filament matching' do
    it 'matches the material, any colour' do
      load('PLA', 'Galaxy Black')

      expect(answer(fit(needs))).to eq [:ready, [
        { code: :filament_matches, message: 'Loaded PLA Galaxy Black matches' }
      ]]
    end

    it 'matches the material and the colour asked, by colour key' do
      load('PLA', 'Galaxy Black')

      expect(answer(fit(needs(colour: ' galaxy  BLACK')))).to eq [:ready, [
        { code: :filament_matches, message: 'Loaded PLA Galaxy Black matches' }
      ]]
    end

    it 'asks for a change of colour' do
      load('PLA', 'Black')

      expect(answer(fit(needs(colour: 'Red')))).to eq [:after_filament_change, [
        { code: :wrong_colour, message: 'Needs PLA Red. PLA Black is loaded here' }
      ]]
    end

    it 'asks for a change of material, naming the colour asked' do
      load('PETG', 'Red')

      expect(answer(fit(needs(colour: 'Red')))).to eq [:after_filament_change, [
        { code: :wrong_material, message: 'Needs PLA Red. PETG is loaded here' }
      ]]
    end

    it 'asks for a filament when nothing is loaded' do
      expect(answer(fit(needs))).to eq [:after_filament_change, [
        { code: :no_filament, message: 'Needs PLA. No filament is loaded here' }
      ]]
    end

    describe 'a material Not known' do
      it 'asks for nothing with Any colour, even of an empty slot' do
        expect(answer(fit(needs(materials: [nil])))).to eq [:ready, [{ code: :any_filament, message: 'Any filament' }]]
      end

      it 'asks for the colour, of any material' do
        load('PETG', 'Red')

        expect(answer(fit(needs(materials: [nil], colour: 'red')))).to eq [:ready, [
          { code: :filament_matches, message: 'Loaded PETG Red matches' }
        ]]
      end

      it 'asks for a change of colour' do
        load('PETG', 'Black')

        expect(answer(fit(needs(materials: [nil], colour: 'Red')))).to eq [:after_filament_change, [
          { code: :wrong_colour, message: 'Needs Red. PETG Black is loaded here' }
        ]]
      end

      it 'asks for a filament of that colour when nothing is loaded' do
        expect(answer(fit(needs(materials: [nil], colour: 'Red')))).to eq [:after_filament_change, [
          { code: :no_filament, message: 'Needs Red. No filament is loaded here' }
        ]]
      end
    end

    describe 'a file with no tool known (a failed summary, not G-code)' do
      let(:unknown) { PrintQueue::Needs.new }

      it 'fits any filament, and no filament' do
        expect(answer(fit(unknown))).to eq [:ready, [{ code: :any_filament, message: 'Any filament' }]]
      end

      it 'fits every printer, whatever its specs' do
        tiny = build(:printer, build_volume_x: 1, build_volume_y: 1, build_volume_z: 1, extruders: 1,
                               materials: %w[TPU])

        expect(described_class.new(needs: unknown, printer: tiny, status: operational)).to be_ready
      end

      it 'checks the first slot for the colour asked' do
        load('PLA', 'Black')

        expect(answer(fit(PrintQueue::Needs.new(colour: 'Red')))).to eq [:after_filament_change, [
          { code: :wrong_colour, message: 'Needs Red. PLA Black is loaded here' }
        ]]
      end
    end

    describe 'several tools' do
      it 'checks only the slots the printer has: tool n in slot n + 1' do
        load('PLA', 'Black')

        expect(answer(fit(needs(materials: %w[PLA PETG])))).to eq [:ready, [
          { code: :filament_matches, message: 'Loaded PLA Black matches' }
        ]]
      end

      it 'names the slot of each tool on a printer with several' do
        printer.filament_slots = 2
        load('PLA', 'Black')
        load('PLA', 'White', slot: 2)

        expect(answer(fit(needs(materials: %w[PLA PETG])))).to eq [:after_filament_change, [
          { code: :wrong_material, message: 'Slot 2: Needs PETG. PLA is loaded here' }
        ]]
        expect(fit(needs(materials: %w[PLA PLA])).reasons.map(&:message)).to eq [
          'Slot 1: Loaded PLA Black matches', 'Slot 2: Loaded PLA White matches'
        ]
      end
    end
  end

  it 'reads the preloaded filaments, the snapshot and the summary without a query' do
    saved = create(:printer)
    create(:printer_loaded_filament, printer: saved)
    saved = Printer.includes(:loaded_filaments).find(saved.id)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      described_class.new(needs:, printer: saved, status: operational).result
    end

    expect(queries).to be_empty
  end

  it 'is read-only' do
    expect { fit(needs).save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
