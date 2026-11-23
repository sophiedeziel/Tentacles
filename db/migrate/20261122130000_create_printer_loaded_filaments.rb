# frozen_string_literal: true

# Global queue, phase 1 (#2935): the filament loaded in each slot of a printer, and the printer columns the queue
# reads later. Additive: nothing reads them yet, every printer starts with no filament set.
#
# No row for a slot means its filament is not set (there is no "empty" row). The unique (printer_id, slot) index keeps
# one filament per slot and serves the foreign key; (material, colour_key) answers "which printers have PLA Black".
class CreatePrinterLoadedFilaments < ActiveRecord::Migration[8.1]
  def change
    create_table :printer_loaded_filaments do |t|
      t.references :printer, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.integer :slot, null: false, default: 1
      t.string :material, null: false
      t.string :colour, null: false
      t.string :colour_key, null: false
      t.timestamps

      t.index %i[printer_id slot], unique: true
      t.index %i[material colour_key]
    end

    change_table :printers, bulk: true do |t|
      t.integer :filament_slots, null: false, default: 1
      t.boolean :takes_jobs, null: false, default: true
    end
  end
end
