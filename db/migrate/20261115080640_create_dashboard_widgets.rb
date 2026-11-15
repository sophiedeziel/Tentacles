# frozen_string_literal: true

class CreateDashboardWidgets < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboard_widgets do |t|
      t.references :dashboard_section, null: false, foreign_key: { on_delete: :cascade }
      t.string :type, null: false # STI: PrinterWidget, PrintQueueWidget
      t.integer :width_units, null: false # grid columns spanned, 1-4
      t.integer :height_units, null: false # grid rows spanned, 1-4
      t.integer :position, null: false
      t.references :printer, foreign_key: true # null = all printers (Print Queue only)
      t.json :options, null: false # per-type keys, see DashboardWidget.widget_options

      t.timestamps
      t.index %i[dashboard_section_id position]
    end
  end
end
