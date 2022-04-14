# frozen_string_literal: true

class CreatePrinterJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :printer_jobs do |t|
      t.string :name
      t.references :printer, null: false, foreign_key: true
      t.integer :executable_id, null: false
      t.string :executable_type, null: false
      t.string :status, null: false, default: 'enqueued'

      t.timestamps
    end
  end
end
