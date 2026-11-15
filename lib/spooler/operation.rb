# typed: true
# frozen_string_literal: true

class Spooler
  class Operation
    attr_reader :job, :printer

    def initialize(printer, job)
      @job = job
      @printer = printer
    end

    def execute
      log 'Not implemented yet'
    end

    def interrupt
      log 'Not implemented yet'
    end

    def track_progress(progress)
      @job.update(progress:)
    end

    def log(message)
      puts "#{' ' * (15 - @printer.name.size)} [ #{@printer.name} ] : #{message}"
    end
  end

  class Print < Operation
    def initialize(printer, job)
      super
      @file = FileRecord.find(job.executable_id)
    end

    def execute
      log '1. Start the print: send the right gcode to octoprint'.cyan
      update_subscribers
      UploadFilesToPrintersJob.perform_now([@file.id], [@printer.id], select: true, print: true)

      log '2. Monitor the print'.cyan

      wait_for_print_to_finish
      update_subscribers
      log '3. Profit.'.green
    end

    def update_subscribers
      @printer.reload.update_subscribers
    end

    private

    # Polls OctoPrint until the print is over. A paused or cancelling print is still under way: its job stays active.
    def wait_for_print_to_finish
      loop do
        job = current_octoprint_job
        family = PrinterStateFamily.for(job.state)
        printing_updates(job) if family == PrinterStateFamily::Printing
        break unless family.in_progress?

        sleep(WAIT_TIME)
      end
    end

    # With the printer's own client: `use` sets it for the current thread only, so concurrent prints don't mix up
    def current_octoprint_job
      @printer.octoprint_client.use { Octoprint::Job.get }
    end

    def printing_updates(job)
      completion = job.progress&.completion
      return if completion.nil? # e.g. while OctoPrint is still "Starting" the print

      progress = completion.ceil

      track_progress(progress)
      log("#{progress}%")
      update_subscribers
    end
  end
end
