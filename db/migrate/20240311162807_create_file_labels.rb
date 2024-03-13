# frozen_string_literal: true

class CreateFileLabels < ActiveRecord::Migration[7.1]
  def change
    create_table :file_labels do |t|
      t.references :file_record, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true

      t.timestamps
    end
  end
end
