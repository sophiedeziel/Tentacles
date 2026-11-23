# typed: true
# frozen_string_literal: true

module PrintQueue
  # A printer an entry is limited to, when its `all_capable` is off ("All that can print it" includes printers added
  # later; a list doesn't). Deleted with the entry or the printer (the database cascades).
  class JobPrinter < ApplicationRecord
    self.table_name = 'print_job_printers'

    belongs_to :job, class_name: 'PrintQueue::Job', foreign_key: :print_job_id, inverse_of: :job_printers
    belongs_to :printer, class_name: '::Printer'

    validates :printer_id, uniqueness: { scope: :print_job_id }
  end
end
