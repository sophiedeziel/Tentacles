# frozen_string_literal: true

class Spooler
  # The global queue's side of a spool (Spooler::Spool), while the queue is on: the copies of its entries (Printer::Jobs
  # with a print_job) are run like the printer's own jobs, but their start, progress and end are the queue's print
  # events (PrintQueue::PrintStart, PrintQueue::PrintProgress through Operation#track_progress, PrintQueue::PrintEnd).
  # After a restart, the spool adopts the copy its printer was printing (#adopt_active_copy).
  module QueueCopies
    # Tries of PrintQueue::PrintEnd while the queue is busy (see #end_copy)
    PRINT_END_ATTEMPTS = 3

    private

    # A copy of a global queue entry, while the global queue is on: its start and its end are the queue's print events.
    # The file is uploaded only once PrintQueue::PrintStart is saved: a copy cancelled since the spool picked it up
    # isn't started.
    def run_copy(job)
      operation = @current_operation = build_operation(job)
      finish_copy(operation, print_copy(operation))
    end

    # After a restart (the spooler's, or this spool's thread), the copy its printer was printing, while the global
    # queue is on. The spool only ever takes enqueued jobs (Printer#next_job): without this, an active copy would stay
    # active for good, its printer busy. The copy is monitored without uploading its file again, then ended. Meanwhile
    # the spool is working (a start_print is ignored), and the printer is busy for the queue (PrintQueue::Readiness:
    # its copy is active).
    def adopt_active_copy
      job = @printer.jobs.where.not(print_job_id: nil).find_by(status: 'active')
      return if job.nil?

      operation = @current_operation = build_operation(job, adopted: true)
      operation.execute
      finish_copy(operation, 'completed')
    end

    # Records PrintQueue::PrintStart, then sends the file and monitors the print: 'completed' once it's over, 'error'
    # when its file couldn't be sent, nil when PrintStart was refused (#refused_start)
    def print_copy(operation)
      start = PrintQueue::PrintStart.new(printer_job: operation.job)
      return refused_start(operation, start) unless start.save

      operation.update_subscribers
      operation.execute
      'completed'
    rescue Printer::Backend::Error => e
      operation.log("Could not start the print: #{e.class}: #{e.message}".red)
      'error'
    end

    # PrintQueue::PrintStart was refused (the copy was cancelled since the spool picked it up, the queue is busy, ...):
    # nothing is sent to the printer, and the copy isn't ended. A copy still enqueued is started by the next
    # start_print or sweep.
    def refused_start(operation, start)
      operation.log("Not starting the print: #{start.errors.full_messages.to_sentence}".red)
      nil
    end

    # The spool is idle before the copy ends: the dispatch pass PrintQueue::PrintEnd asks for can start the printer's
    # next copy (Spooler#send_command ignores a start_print while the spool is working).
    def finish_copy(operation, result)
      @active = @start_job_after_finish
      @current_operation = nil
      return if result.nil?

      end_copy(operation, result)
      operation.update_subscribers
    rescue StandardError => e
      operation.log("Could not notify the subscribers: #{e.class}: #{e.message}".red)
    end

    # PrintQueue::PrintEnd, retried when the queue is busy (a deadlock, a lock wait timeout): a copy left active keeps
    # its printer busy. Its other errors are logged.
    def end_copy(operation, result)
      attempts = 0
      begin
        PrintQueue::PrintEnd.new(printer_job: operation.job, result:).save!
      rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout
        retry if (attempts += 1) < PRINT_END_ATTEMPTS
        raise
      end
    rescue StandardError => e
      operation.log("Could not end the copy: #{e.class}: #{e.message}".red)
    end
  end
end
