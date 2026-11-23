# typed: true
# frozen_string_literal: true

module PrintQueue
  # A print event: the copy's print is starting. Its spool records it before uploading the file, and uploads only
  # when it's saved. See PrintQueue::CopyOperation.
  #
  #   start = PrintQueue::PrintStart.new(printer_job:)
  #   start.save          # => false when refused: the spool doesn't start the print
  #   start.errors[:base] # => ['Copy 2 of cube.gcode has already ended']
  #
  # The copy turns active, with its started_at (kept when it already has one), and its printer's queue is pushed.
  # Only an enqueued copy starts: under the queue's lock, so a copy cancelled (PrintQueue::CopyCancellation) after its
  # spool picked it up is refused rather than turned active again.
  class PrintStart < CopyOperation
    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal
      not_a_copy || case printer_job.status
                    when 'enqueued' then nil
                    when 'active' then "#{copy_name} has already started"
                    else "#{copy_name} has already ended"
                    end
    end

    # @override
    #: -> void
    def change
      printer_job.update!(status: 'active', started_at: printer_job.started_at || Time.current)
    end
  end
end
