# typed: true
# frozen_string_literal: true

module PrintQueue
  # Removes the copies of an entry that are still waiting: its copies become the ones done, printing or failed, so the
  # entry leaves the queue once its printing copies end. A printing copy is never touched. See PrintQueue::Operation.
  #
  #   removal = PrintQueue::WaitingCopiesRemoval.new(job:)
  #   removal.save          # => false when no copy is waiting
  #   removal.errors[:base] # => ['cube.gcode has no copies waiting']
  #
  # An entry with no copy dispatched yet has nothing left: it's deleted (`removal.job_deleted?`).
  class WaitingCopiesRemoval < EntryOperation
    validate :allowed, unless: :refused?

    # Whether the entry was deleted, its copies all waiting
    #: -> bool
    def job_deleted? = @job_deleted == true

    private

    #: -> String?
    def refusal
      no_longer_queued || ("#{filename} has no copies waiting" if job.waiting_count.zero?)
    end

    # @override
    #: -> void
    def change
      kept = job.done_count + job.printing_count + job.failed_count
      if kept.zero?
        job.destroy!
        @job_deleted = true
      else
        job.update!(copies: kept)
      end
    end
  end
end
