# typed: true
# frozen_string_literal: true

module PrintQueue
  # Base of the operations on one copy of an entry (`printer_job`, a Printer::Job with a print_job):
  # PrintQueue::CopyCancellation, and the print events the spool records under the queue's lock (PrintQueue::PrintStart,
  # PrintQueue::PrintEnd). See PrintQueue::Operation. The copy is read again under the queue's lock, and its printer's
  # queue is pushed.
  # @abstract
  class CopyOperation < Operation
    self.abstract_class = true

    # The Printer::Job
    attribute :printer_job

    validates :printer_job, presence: true

    private

    #: -> void
    def reload_records
      printer_job.reload
    end

    #: -> Array[Printer]
    def pushed_printers = [printer_job.printer]

    # The refusal of a job of the printer's own queue
    #: -> String?
    def not_a_copy
      "#{printer_job.name} isn't a copy of a queue entry" unless printer_job.copy?
    end

    #: -> bool
    def finished? = Printer::Job::UNFINISHED_STATUSES.exclude?(printer_job.status)

    #: -> String
    def copy_name = "Copy #{printer_job.copy_number} of #{printer_job.print_job.item.filename}"
  end
end
