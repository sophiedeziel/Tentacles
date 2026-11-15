# frozen_string_literal: true

class CreateDashboardSections < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboard_sections do |t|
      t.string :title # null only for the first section
      t.integer :position, null: false

      t.timestamps
    end
  end
end
