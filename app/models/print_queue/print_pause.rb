# typed: true
# frozen_string_literal: true

module PrintQueue
  # A print event: the copy's print paused. Nothing is stored in phase 3 (the copy stays active): its printer's queue is
  # pushed. The fake connector fires it (global queue phase 3, PR 6). See PrintQueue::CopyEvent.
  #
  #   PrintQueue::PrintPause.new(printer_job:).save
  class PrintPause < CopyEvent
    private

    #: -> void
    def persist
      PrintQueue.push_changed([printer_job.printer])
    end
  end
end
