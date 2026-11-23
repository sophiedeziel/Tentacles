# frozen_string_literal: true

# Global queue, phase 3 (#2937): the queue's tables, and the columns its copies and printers need. Additive: nothing
# writes them yet, and the per-printer queue (printer_jobs without a print_job_id) is untouched.
#
# print_jobs holds the entries of the global queue: a file and a number of copies. Each copy is a printer_jobs row with
# its print_job_id and copy_number. The file's foreign key doesn't cascade: a queued file can't be deleted.
# print_job_printers lists the printers an entry is limited to when all_capable is off. print_queue_settings holds a
# single row.
class CreatePrintQueue < ActiveRecord::Migration[8.1]
  def change
    create_table :print_jobs do |t|
      t.references :file_record, null: false, foreign_key: true
      t.integer :copies, null: false, default: 1
      t.integer :position, null: false, index: true
      t.boolean :held, null: false, default: false
      t.boolean :same_printer, null: false, default: false
      t.references :bound_printer, foreign_key: { to_table: :printers, on_delete: :nullify }
      # "All that can print it": printers added later are included
      t.boolean :all_capable, null: false, default: true
      # The colour asked for, as typed, and its matching key (Filament.colour_key). Null: Any colour
      t.string :colour
      t.string :colour_key
      t.timestamps
    end

    create_table :print_job_printers do |t|
      t.references :print_job, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :printer, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps

      t.index %i[print_job_id printer_id], unique: true
    end

    create_table :print_queue_settings do |t|
      t.boolean :dispatch_paused, null: false, default: false
      t.timestamps
    end

    change_table :printer_jobs, bulk: true do |t|
      t.bigint :print_job_id
      t.integer :copy_number
      t.datetime :started_at
      t.datetime :finished_at
      # The printer's loaded filaments when the copy was dispatched: [{ "slot" => 1, "material" => "PLA", ... }]
      t.json :filament
      t.datetime :bed_cleared_at
      # 'person' or 'automatic'
      t.string :bed_cleared_by
    end
    # Before its foreign key, which needs it: rolling back removes the key first
    add_index :printer_jobs, %i[print_job_id status]
    add_foreign_key :printer_jobs, :print_jobs, on_delete: :nullify

    add_column :printers, :clears_own_bed, :boolean, null: false, default: false
  end
end
