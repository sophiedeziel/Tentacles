# typed: true
# frozen_string_literal: true

module PrintQueue
  # A print event: the copy's print progressed. Its spool records it at each poll while the printer prints. Writes the
  # copy's progress, without a push (like the jobs of a printer's own queue: progress is written twice a second). See
  # PrintQueue::CopyEvent.
  #
  #   PrintQueue::PrintProgress.new(printer_job:, progress: 43).save
  class PrintProgress < CopyEvent
    # Percent done, 0 to 100
    attribute :progress, :float

    validates :progress, numericality: { in: 0..100 }

    private

    #: -> void
    def persist
      printer_job.update!(progress:)
    end
  end
end
