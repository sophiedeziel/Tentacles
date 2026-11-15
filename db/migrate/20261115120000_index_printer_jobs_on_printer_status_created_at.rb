# frozen_string_literal: true

# The queue, the next job and the history all filter a printer's jobs by status and sort them by time. The new index
# starts with printer_id, so it also serves the printers foreign key, and the old printer_id index goes.
class IndexPrinterJobsOnPrinterStatusCreatedAt < ActiveRecord::Migration[8.1]
  def change
    change_table :printer_jobs, bulk: true do |t|
      t.index %i[printer_id status created_at]
      t.remove_index :printer_id, name: 'index_printer_jobs_on_printer_id'
    end
  end
end
