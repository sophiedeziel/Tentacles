class AddProgressToPrinterJob < ActiveRecord::Migration[7.0]
  def change
    add_column :printer_jobs, :progress, :float, default: 0, null: false
  end
end
