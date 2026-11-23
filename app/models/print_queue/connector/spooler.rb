# typed: true
# frozen_string_literal: true

module PrintQueue
  class Connector
    # The connector of phase 3: a copy is started by the printer's spool (lib/spooler.rb), which uploads its file and
    # monitors its print, and the print is paused, resumed or cancelled through the printer's API.
    #
    #   PrintQueue::Connector::Spooler.new.start(printer_job) # publishes start_print for its printer
    class Spooler < Connector
      # Asks the spooler to start the printer's spool, which takes the copy as its printer's next job
      # (Printer#next_job). Best effort: the copy is committed already, so a Redis error is logged, never raised, and
      # the spooler's sweep starts the copy (PrintQueue::SWEEP_INTERVAL).
      # @override
      #: (Printer::Job printer_job) -> void
      def start(printer_job)
        T.must(printer_job.printer).notify_spooler(Printer::SpoolerCommand::StartPrint)
      rescue Redis::BaseError, ConnectionPool::TimeoutError => e
        Rails.logger.error('[PrintQueue::Connector::Spooler] Could not publish start_print for printer ' \
                           "#{printer_job.printer_id}: #{e.class}: #{e.message}")
      end

      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def pause(printer_job) = saved(Printer::Pause.new(printer: printer_job.printer))

      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def resume(printer_job) = saved(Printer::Resumption.new(printer: printer_job.printer))

      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def cancel(printer_job) = saved(Printer::Cancellation.new(printer: printer_job.printer))

      private

      #: (Printer::Command command) -> Printer::Command
      def saved(command)
        command.save
        command
      end
    end
  end
end
