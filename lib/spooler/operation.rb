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
      super(printer, job)
      @file = FileRecord.find(job.executable_id)
    end

    def execute
      Octoprint.configure(host: @printer.octoprint_uri, api_key: @printer.octoprint_key)
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

    def wait_for_print_to_finish
      printing = true
      while printing
        job = Octoprint::Job.get
        printing = job.state == 'Printing'
        printing_updates(job)

        sleep(WAIT_TIME)
      end
    end

    def printing_updates(job)
      return unless job.state == 'Printing'

      progress = job.progress.completion.ceil

      track_progress(progress)
      log("#{progress}%")
      update_subscribers
    end
  end
end
