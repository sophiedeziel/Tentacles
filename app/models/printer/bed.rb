# typed: true
# frozen_string_literal: true

class Printer
  # The printer's bed, for the global queue: whether the last print is still on it, keeping the printer from taking a
  # job (PrintQueue::Readiness's :bed_not_cleared) until it's cleared (PrintQueue::BedClearance), or the printer clears
  # it itself (`clears_own_bed`, PrintQueue::PrintEnd).
  #
  #   printer.bed_needs_clearing?             # => true
  #   printer.bed_to_clear                    # => the Printer::Job still on the bed
  #   Printer.ids_with_bed_to_clear([1, 2])   # => #<Set: {2}>, in one query (PrintQueue::Dispatch)
  #
  # The print on the bed is the printer's last started job (by started_at, then id), when it has finished and its bed
  # wasn't cleared since. Only the global queue's copies have a started_at (PrintQueue::PrintStart): a printer that
  # never printed one has nothing to clear, and neither has a copy cancelled before it started. A copy that started,
  # then ended in any way (completed, error, cancelled), leaves its print on the bed.
  module Bed
    extend ActiveSupport::Concern

    class_methods do
      # The printers among these whose bed needs clearing, in one query: each printer's last started job, ranked with a
      # window function
      #: (Array[Integer] printer_ids) -> Set[Integer]
      def ids_with_bed_to_clear(printer_ids)
        return Set.new if printer_ids.empty?

        last_started = Printer::Job.where(printer_id: printer_ids).where.not(started_at: nil).select(
          :printer_id, :finished_at, :bed_cleared_at,
          'ROW_NUMBER() OVER (PARTITION BY printer_id ORDER BY started_at DESC, id DESC) AS recency'
        )
        Printer::Job.from(last_started, :printer_jobs).where(recency: 1, bed_cleared_at: nil)
                    .where.not(finished_at: nil).pluck(:printer_id).to_set
      end
    end

    #: -> bool
    def bed_needs_clearing? = !bed_to_clear.nil?

    # The print still on the bed, nil when there's none (the last started print is under way or cleared, or no print
    # ever started)
    #: -> Printer::Job?
    def bed_to_clear
      last = T.bind(self, Printer).jobs.where.not(started_at: nil).order(started_at: :desc, id: :desc).first
      last if last&.finished_at && last.bed_cleared_at.nil?
    end
  end
end
