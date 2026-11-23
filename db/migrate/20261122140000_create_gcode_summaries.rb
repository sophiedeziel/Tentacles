# frozen_string_literal: true

# Global queue, phase 2 (#2936): what a G-code file needs to print (time, filament per tool, footprint, tool changes
# and M600 pauses), read once by Gcode::Summary and stored so the queue can read it without opening the file.
# Additive: nothing reads it yet, and the editor's analysis (Gcode::Analysis) is untouched.
#
# One gcode_summaries row per file, one gcode_summary_tools row per tool. Every value is nullable: null means Not
# known. Both cascade when their parent is deleted.
class CreateGcodeSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :gcode_summaries do |t|
      t.references :file_record, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: 'pending'
      t.integer :analysis_version, null: false, default: 0
      t.datetime :analysed_at
      t.string :error
      t.string :slicer
      t.string :slicer_version
      t.integer :print_seconds
      # In mm: the box of the extruding moves (skirt, brim and prime line included), or the one the slicer states
      t.decimal :min_x, precision: 7, scale: 2
      t.decimal :max_x, precision: 7, scale: 2
      t.decimal :min_y, precision: 7, scale: 2
      t.decimal :max_y, precision: 7, scale: 2
      t.decimal :max_z, precision: 7, scale: 2
      t.string :footprint_source
      t.integer :tool_count
      t.integer :tool_changes
      # One { line, z, layer } per M600, in file order
      t.json :filament_changes, null: false, default: -> { '(JSON_ARRAY())' }
      t.timestamps
    end

    create_table :gcode_summary_tools do |t|
      t.references :gcode_summary, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.integer :tool, null: false
      t.string :material
      t.string :material_raw
      t.string :colour_hex
      t.decimal :grams, precision: 8, scale: 2
      t.decimal :millimetres, precision: 10, scale: 1
      t.timestamps

      t.index %i[gcode_summary_id tool], unique: true
      t.index :material
    end
  end
end
