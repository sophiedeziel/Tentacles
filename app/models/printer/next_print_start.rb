# typed: true
# frozen_string_literal: true

class Printer
  # Asks the spooler to start the next job of the printer's queue, when Printer.start_next_allowed? with the LIVE
  # state read from the printer (Printer.canStartNext uses the monitor's last snapshot instead). See Printer::Command.
  #
  #   start = Printer::NextPrintStart.new(printer:, expected_job_id: '12')
  #   start.save          # => false when refused, when the printer fails or when the spooler can't be asked
  #   start.errors[:base] # => ["Prusa MK4's next job is now gear.gcode"]
  #
  # The spooler starts the job asynchronously (and publishes the new state), so this only queues the command, and no
  # monitor tick follows: the printer is still OPERATIONAL until the spooler uploads the file and starts it.
  class NextPrintStart < Command
    # The spooler can't be asked to start the job (Redis is down)
    class SpoolerUnreachable < StandardError; end

    # The next job the user confirmed for (a Printer::Job id), or nil not to check it
    attribute :expected_job_id, :string

    rescue_into_errors SpoolerUnreachable

    skip_callback :save, :after, :refresh_status

    private

    def refusal(family)
      blocker = Printer.start_next_blocker(state_family: family, enqueued: printer.queue.exists?,
                                           active: printer.jobs.exists?(status: 'active'))
      case blocker
      when :active_job then "#{printer.name} already has an active job"
      when :empty_queue then "#{printer.name} has nothing in its queue"
      when :not_ready then "#{printer.name} is not ready to print"
      end
    end

    sig { void }
    def still_the_confirmed_job
      expected = expected_job_id
      message = next_job_change(expected) if expected
      errors.add(:base, message) if message
    end

    # The next job changed since the user confirmed (enqueued, removed or reordered): don't start another file
    sig { params(expected_job_id: String).returns(T.nilable(String)) }
    def next_job_change(expected_job_id)
      next_job = printer.next_job
      return "#{printer.name} has nothing in its queue" if next_job.nil?
      return if next_job.id.to_s == expected_job_id

      "#{printer.name}'s next job is now #{next_job.executable.try(:filename) || next_job.name}"
    end

    # Publishing to the spooler goes through Redis rather than the printer
    def persist
      printer.notify_spooler(:start_print)
    rescue Redis::BaseError, ConnectionPool::TimeoutError => e
      Rails.logger.error("[Printer::NextPrintStart] Could not publish start_print for printer #{printer.id}: " \
                         "#{e.message}")
      raise SpoolerUnreachable, "Could not ask the spooler to start #{printer.name}'s next print"
    end
  end
end
