# frozen_string_literal: true

class Spooler
  class Operation
    def initialize(printer)
      @printer = printer
    end

    def execute
      log 'Not implemented yet'
    end

    def interrupt
      log 'Not implemented yet'
    end

    def log(message)
      puts "#{' ' * (15 - @printer.name.size)} [ #{@printer.name} ] : #{message}"
    end
  end

  class Print < Operation
    def initialize(printer, file_id)
      super(printer)
      @file = FileManager::File.find(file_id)
    end

    def execute
      Octoprint.configure(host: @printer.octoprint_uri, api_key: @printer.octoprint_key)
      log '1. Start the print: send the right gcode to octoprint'.cyan
      UploadFilesToPrintersJob.perform_now([@file.id], [@printer.id], select: true, print: true)

      log '2. Monitor the print'.cyan
      wait_for_print_to_finish
      log '3. Profit.'.green
    end

    private

    def wait_for_print_to_finish
      printing = true
      while printing
        job = Octoprint::Job.get
        printing = job.state == 'Printing'

        log("#{job.progress.completion.ceil}%") if printing
        sleep(WAIT_TIME)
      end
    end
  end
end
