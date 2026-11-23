# typed: true
# frozen_string_literal: true

module PrintQueue
  # Base of the operations on one entry of the queue (`job`): PrintQueue::Move, PrintQueue::Hold, ... See
  # PrintQueue::Operation. The entry is read again under the queue's lock, and its bound printer's queue is pushed.
  # @abstract
  class EntryOperation < Operation
    self.abstract_class = true

    # The PrintQueue::Job
    attribute :job

    validates :job, presence: true

    private

    # Its counts too (PrintQueue::Job#reload forgets them)
    #: -> void
    def reload_records
      job.reload
    end

    #: -> Array[Printer]
    def pushed_printers = [job.bound_printer].compact

    # The refusal of the operations that only make sense on an entry still in the queue
    #: -> String?
    def no_longer_queued
      "#{filename} is no longer in the queue" unless job.unfinished?
    end

    #: -> String
    def filename = job.item.filename
  end
end
