# frozen_string_literal: true

# Global queue, phase 3 (#2937): when a copy's cancellation was asked (PrintQueue::CopyCancellation). A copy under way
# stays active until its print ends: the print ended handler then ends it cancelled, whatever the printer reported.
# Additive: null for every existing job.
class AddCancelRequestedAtToPrinterJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :printer_jobs, :cancel_requested_at, :datetime
  end
end
