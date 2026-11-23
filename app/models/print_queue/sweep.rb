# typed: true
# frozen_string_literal: true

module PrintQueue
  # What the spooler does every SWEEP_INTERVAL while the global queue is on: a dispatch pass, then it finds the
  # printers with an enqueued copy, so that the spooler starts their spools when they're idle.
  #
  #   sweep = PrintQueue::Sweep.new
  #   sweep.save!
  #   sweep.printer_ids # => [1, 3]: the spooler resumes their spools unless they're working
  #
  # It catches up on what a message left behind: a dispatch request published while the spooler was down (Redis
  # doesn't keep it), and a start_print the spooler ignored because the spool still looked busy (Spooler#send_command)
  # or never got. Does nothing while the global queue is off.
  class Sweep < ApplicationModel
    # The printers with an enqueued copy (a Printer::Job with a print_job), after save
    #: -> Array[Integer]
    def printer_ids = @printer_ids || []

    private

    #: -> void
    def persist
      return unless PrintQueue.enabled?

      dispatch
      @printer_ids = Printer::Job.enqueued.where.not(print_job_id: nil).distinct.pluck(:printer_id) #: Array[Integer]?
    end

    # The queue being busy doesn't keep the enqueued copies from being started: the next sweep dispatches. Other
    # errors raise
    #: -> void
    def dispatch
      PrintQueue::Dispatch.new.save!
    rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout => e
      Rails.logger.warn("[PrintQueue::Sweep] Dispatch pass skipped: #{e.class}: #{e.message}")
    end
  end
end
