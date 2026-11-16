# frozen_string_literal: true

# Favorites, and what the "About This Printer" card shows (see Printer::Specs). Every spec column is nullable: nil
# means "never set", and autofill only fills nil columns. `materials` defaults to [] in the model, not here (MySQL
# JSON columns can't have a literal default).
class AddFavoriteAndSpecsToPrinters < ActiveRecord::Migration[8.1]
  def change
    change_table :printers, bulk: true do |t|
      t.boolean :favorite, null: false, default: false
      t.string :brand, limit: 100
      t.string :model, limit: 100
      t.string :firmware, limit: 100
      t.string :firmware_version, limit: 50
      t.decimal :build_volume_x, precision: 6, scale: 1
      t.decimal :build_volume_y, precision: 6, scale: 1
      t.decimal :build_volume_z, precision: 6, scale: 1
      t.decimal :build_diameter, precision: 6, scale: 1
      t.string :bed_shape
      t.integer :extruders
      t.decimal :nozzle_diameter, precision: 4, scale: 2
      t.integer :max_hotend_temp
      t.integer :max_bed_temp
      # nil = unknown: the printer's server may not report them
      t.boolean :heated_bed # rubocop:disable Rails/ThreeStateBooleanColumn
      t.boolean :heated_chamber # rubocop:disable Rails/ThreeStateBooleanColumn
      t.boolean :webcam # rubocop:disable Rails/ThreeStateBooleanColumn
      t.json :materials
    end
  end
end
