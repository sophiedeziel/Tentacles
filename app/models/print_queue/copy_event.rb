# typed: true
# frozen_string_literal: true

module PrintQueue
  # Base of the print events of a copy (`printer_job`, a Printer::Job with a print_job) that don't take the queue's
  # lock: PrintQueue::PrintProgress and PrintQueue::PrintPause. See PrintQueue::Event.
  # @abstract
  class CopyEvent < Event
    self.abstract_class = true

    # The Printer::Job
    attribute :printer_job

    validates :printer_job, presence: true
    validate :a_copy

    private

    #: -> void
    def a_copy
      errors.add(:base, "#{printer_job.name} isn't a copy of a queue entry") if printer_job && !printer_job.copy?
    end
  end
end
