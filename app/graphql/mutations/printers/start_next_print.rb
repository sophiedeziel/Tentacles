# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Asks the spooler to start the next job of a printer's queue, when Printer.start_next_allowed? with the LIVE
    # state read from OctoPrint (Printer.canStartNext uses the monitor's last snapshot instead).
    class StartNextPrint < PrinterAction
      description 'Mutation to start the next print in the queue for a printer'

      argument :expected_job_id, ID, required: false,
                                     description: 'The next job the user confirmed for: refuses when the queue ' \
                                                  'has another job first'

      private

      def refusal(printer, family)
        blocker = ::Printer.start_next_blocker(state_family: family, enqueued: printer.queue.exists?,
                                               active: printer.jobs.exists?(status: 'active'))
        case blocker
        when :active_job then "#{printer.name} already has an active job"
        when :empty_queue then "#{printer.name} has nothing in its queue"
        when :not_ready then "#{printer.name} is not ready to print"
        end
      end

      # The next job changed since the user confirmed (enqueued, removed or reordered): don't start another file
      def unexpected_job(printer, _job)
        expected = @expected_job_id
        return if expected.nil?

        next_job = printer.next_job
        return "#{printer.name} has nothing in its queue" if next_job.nil?
        return if next_job.id.to_s == expected.to_s

        "#{printer.name}'s next job is now #{next_job.executable.try(:filename) || next_job.name}"
      end

      # The spooler starts the job asynchronously (and publishes the new state), so this only queues the command
      def send_command(printer)
        printer.start_print
      end

      # The printer is still OPERATIONAL until the spooler uploads the file and starts it: a tick wouldn't show anything
      def refresh_after_command?
        false
      end

      # Publishing to the spooler goes through Redis rather than OctoPrint
      def run(printer)
        super
      rescue Redis::BaseError, ConnectionPool::TimeoutError => e
        Rails.logger.error("[StartNextPrint] Could not publish start_print for printer #{printer.id}: #{e.message}")
        failure(printer, "Could not ask the spooler to start #{printer.name}'s next print")
      end
    end
  end
end
