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

      # Pause, resume and cancel are sent only while the printer still prints the copy's file (Printer::Command's
      # expected_file_name guard): a copy never pauses or cancels another print, e.g. one started on the printer itself.
      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def pause(printer_job) = saved(Printer::Pause.new(**command_attributes(printer_job)))

      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def resume(printer_job) = saved(Printer::Resumption.new(**command_attributes(printer_job)))

      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def cancel(printer_job) = saved(Printer::Cancellation.new(**command_attributes(printer_job)))

      private

      # The copy's name is its file's name: the name it's uploaded under, which the printer reports back
      #: (Printer::Job printer_job) -> Hash[Symbol, untyped]
      def command_attributes(printer_job) = { printer: printer_job.printer, expected_file_name: printer_job.name }

      #: (Printer::Command command) -> Printer::Command
      def saved(command)
        command.save
        command
      end
    end
  end
end
