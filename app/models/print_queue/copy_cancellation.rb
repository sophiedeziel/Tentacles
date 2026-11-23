# typed: true
# frozen_string_literal: true

module PrintQueue
  # Cancels a copy of an entry (a Printer::Job with a print_job). See PrintQueue::CopyOperation.
  #
  #   cancellation = PrintQueue::CopyCancellation.new(printer_job:)
  #   cancellation.save          # => false when refused, or when the printer refused or failed
  #   cancellation.errors[:base] # => ['Copy 2 of cube.gcode has already ended']
  #
  # - An enqueued copy (not started yet) ends `cancelled` now, and a dispatch pass is asked for: its printer is free.
  #   Its spool can't start it anymore: PrintQueue::PrintStart, under the same lock, only starts an enqueued copy.
  # - A copy under way (active): the printer is asked to cancel its print, through the queue's connector
  #   (PrintQueue.connector#cancel: Printer::Cancellation by default, whose refusals and errors come back in
  #   `errors`). The copy stays active until its print ends: the print ended handler
  #   (PrintQueue::PrintEnd) then ends it `cancelled`, seeing `cancel_requested_at`, and asks for the dispatch pass.
  #   Asking again sends the cancel again.
  # A cancelled copy uses up its copy, like a failed one: printing it again is raising the entry's copies.
  class CopyCancellation < CopyOperation
    validate :allowed, unless: :refused?

    private

    #: -> void
    def persist
      printer_job.status == 'active' ? cancel_print : super
    end

    #: -> String?
    def refusal
      not_a_copy || ("#{copy_name} has already ended" if finished?)
    end

    # @override
    #: -> void
    def change
      # Started by its spool since it was validated: it needs the printer to cancel it
      if printer_job.status == 'active'
        raise Refused, "#{copy_name} has just started, cancel it again to stop its print"
      end

      now = Time.current
      printer_job.update!(status: 'cancelled', finished_at: now, cancel_requested_at: now)
    end

    # Outside the queue's lock: it calls the printer, through the queue's connector (PrintQueue.connector)
    #: -> void
    def cancel_print
      printer_errors = PrintQueue.connector.cancel(printer_job).errors
      raise Refused, printer_errors.full_messages.to_sentence if printer_errors.any?

      printer_job.update!(cancel_requested_at: Time.current) if printer_job.cancel_requested_at.nil?
      PrintQueue.push_changed(pushed_printers)
    end

    #: -> bool
    def dispatches? = true
  end
end
