# frozen_string_literal: true


module Spooler
  class Operation
    def initialize(printer)
      @printer = printer
    end

    def execute
      puts "Not implemented yet"
    end

    def log(message)
      puts "#{" " * (15 - @printer[:name].size) } [ #{@printer[:name]} ] : #{message}"
    end
  end

  class Print < Operation
    def initialize(printer, file)
      super(printer)
      @file = file
    end

    def execute
      log "1. Start the print the right gcode to octoprint"

      Octoprint.configure(host: @printer[:octoprint_uri], api_key: @printer[:octoprint_key])
      Octoprint::Files.upload(@file[:path], select: true, print: true)

      log "2. Monitor the print"

      printing = true
      while(printing)
        job = Octoprint::Job.get
        printing = job.state == "Printing"

        log(job.progress.completion.ceil.to_s + '%')
      end

      log "3. Profit.".green
    end
  end
end
