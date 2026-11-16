# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261116130000_turn_on_queue_table_in_default_layout')

RSpec.describe TurnOnQueueTableInDefaultLayout do
  let(:migration) { described_class.new.tap { |migration| migration.verbose = false } }
  let(:section) { DashboardSection.create!(position: 0) }
  let(:saved_off) { { 'now_printing' => true, 'start_next' => true, 'row_per_printer' => false, 'history' => false } }

  def queue(width_units, height_units, options = {})
    PrintQueueWidget.create!(dashboard_section: section, width_units:, height_units:, position: 0, options:,
                             updated_at: Time.utc(2020, 1, 1))
  end

  describe '#up' do
    it "turns on one row per printer and history in the default layout's queue, which has no options" do
      default = queue(4, 2)
      bigger = queue(4, 4)

      migration.up

      [default, bigger].each do |widget|
        expect(widget.reload).to have_attributes(row_per_printer: true, history: true, now_printing: true)
      end
    end

    it 'keeps the options saved from the editor, which may have turned the table off on purpose' do
      saved = queue(4, 2, saved_off)

      migration.up

      expect(saved.reload.options).to eq(saved_off)
    end

    it 'leaves the smaller queues and the printer widgets alone' do
      large = queue(2, 2)
      printer_widget = PrinterWidget.create!(dashboard_section: section, printer: create(:printer), width_units: 4,
                                             height_units: 2, position: 1)

      migration.up

      expect([large.reload.options, printer_widget.reload.options]).to eq([{}, {}])
    end

    it 'does not touch updated_at' do
      default = queue(4, 2)

      migration.up

      expect(default.reload.updated_at).to eq Time.utc(2020, 1, 1)
    end
  end

  describe '#down' do
    it 'gives the migrated queues their empty options back, and keeps the saved ones' do
      default = queue(4, 2)
      saved = queue(4, 4, saved_off.merge('row_per_printer' => true, 'history' => true))
      migration.up

      migration.down

      expect(default.reload.options).to eq({})
      expect(saved.reload.options).to eq(saved_off.merge('row_per_printer' => true, 'history' => true))
    end
  end
end
