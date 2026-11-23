# typed: true
# frozen_string_literal: true

module PrintQueue
  # Cancels a copy of an entry (a Printer::Job with a print_job). See PrintQueue::Operation.
  #
  #   cancellation = PrintQueue::CopyCancellation.new(printer_job:)
  #   cancellation.save          # => false when refused, or when the printer refused or failed
  #   cancellation.errors[:base] # => ['Copy 2 of cube.gcode has already ended']
  #
  # - An enqueued copy (not started yet) ends `cancelled` now, and a dispatch pass is asked for: its printer is free.
  # - A copy under way (active): the printer is asked to cancel its print (Printer::Cancellation, whose refusals and
  #   errors come back in `errors`). The copy stays active until its print ends: the print ended handler then ends it
  #   `cancelled`, seeing `cancel_requested_at`, and asks for the dispatch pass. Asking again sends the cancel again.
  # A cancelled copy uses up its copy, like a failed one: printing it again is raising the entry's copies.
  class CopyCancellation < Operation
    # The Printer::Job
    attribute :printer_job

    validates :printer_job, presence: true
    validate :allowed, unless: :refused?

    private

    #: -> void
    def persist
      printer_job.status == 'active' ? cancel_print : super
    end

    #: -> String?
    def refusal
      return "#{printer_job.name} isn't a copy of a queue entry" if printer_job.print_job_id.nil?

      "#{copy_name} has already ended" unless Printer::Job::UNFINISHED_STATUSES.include?(printer_job.status)
    end

    #: -> void
    def reload_records
      printer_job.reload
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

    # Outside the queue's lock: it calls the printer
    #: -> void
    def cancel_print
      cancellation = Printer::Cancellation.new(printer: printer_job.printer)
      raise Refused, cancellation.errors.full_messages.to_sentence unless cancellation.save

      printer_job.update!(cancel_requested_at: Time.current) if printer_job.cancel_requested_at.nil?
      PrintQueue.push_changed(pushed_printers)
    end

    #: -> Array[Printer]
    def pushed_printers = [printer_job.printer]

    #: -> bool
    def dispatches? = true

    #: -> String
    def copy_name = "Copy #{printer_job.copy_number} of #{printer_job.print_job.item.filename}"
  end
end
