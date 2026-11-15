# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Asks the spooler to start the next job of a printer's queue, when Printer.start_next_allowed? with the LIVE
    # state read from OctoPrint (Printer.canStartNext uses the monitor's last snapshot instead).
    class StartNextPrint < PrinterAction
      description 'Mutation to start the next print in the queue for a printer'

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
