# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261116130000_turn_on_queue_table_in_default_layout')

# This migration runs before RenameStoredClassNamesToDomainNamespaces: the widgets are stored with their old type
# names ('PrintQueueWidget'), which the current models can't load, so the results are read without instantiating them.
RSpec.describe TurnOnQueueTableInDefaultLayout do
  let(:migration) { described_class.new.tap { |migration| migration.verbose = false } }
  let(:section) { Dashboard::Section.create!(position: 0) }
  let(:saved_off) { { 'now_printing' => true, 'start_next' => true, 'row_per_printer' => false, 'history' => false } }
  let(:table_on) { { 'row_per_printer' => true, 'history' => true } }

  def queue(width_units, height_units, options = {})
    stored_as('PrintQueueWidget', Dashboard::PrintQueueWidget, width_units:, height_units:, options:)
  end

  def stored_as(old_type, model, **attributes)
    widget = model.create!(section:, position: 0, updated_at: Time.utc(2020, 1, 1), **attributes)
    widget.update_columns(type: old_type) # rubocop:disable Rails/SkipsModelValidations -- the type as stored back then
    widget.id
  end

  def options(id)
    Dashboard::Widget.where(id:).pick(:options)
  end

  describe '#up' do
    it "turns on one row per printer and history in the default layout's queue, which has no options" do
      default = queue(4, 2)
      bigger = queue(4, 4)

      migration.up

      expect([options(default), options(bigger)]).to eq([table_on, table_on])
    end

    it 'keeps the options saved from the editor, which may have turned the table off on purpose' do
      saved = queue(4, 2, saved_off)

      migration.up

      expect(options(saved)).to eq(saved_off)
    end

    it 'leaves the smaller queues and the printer widgets alone' do
      large = queue(2, 2)
      printer_widget = stored_as('PrinterWidget', Dashboard::PrinterWidget,
                                 printer: create(:printer), width_units: 4, height_units: 2)

      migration.up

      expect([options(large), options(printer_widget)]).to eq([{}, {}])
    end

    it 'does not touch updated_at' do
      default = queue(4, 2)

      migration.up

      expect(Dashboard::Widget.where(id: default).pick(:updated_at)).to eq Time.utc(2020, 1, 1)
    end
  end

  describe '#down' do
    it 'gives the migrated queues their empty options back, and keeps the saved ones' do
      default = queue(4, 2)
      saved = queue(4, 4, saved_off.merge(table_on))
      migration.up

      migration.down

      expect(options(default)).to eq({})
      expect(options(saved)).to eq(saved_off.merge(table_on))
    end
  end
end
