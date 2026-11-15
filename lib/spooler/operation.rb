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
    # Consecutive failed polls (at least 5 minutes at WAIT_TIME) before the print stops being monitored
    MAX_POLL_FAILURES = 600
    # OPERATIONAL polls (at least 1 minute at WAIT_TIME) to wait for the print to start once the file is uploaded.
    # PrusaLink can still report the printer IDLE or BUSY for a moment after an upload with Print-After-Upload.
    MAX_START_POLLS = 120

    def initialize(printer, job)
      super
      @file = FileRecord.find(job.executable_id)
    end

    # Raises the upload's errors (PrinterBackends::Error): the print can't start
    def execute
      log '1. Start the print: upload the file to the printer'.cyan
      update_subscribers
      UploadFilesToPrintersJob.perform_now([@file.id], [@printer.id], print: true)

      log '2. Monitor the print'.cyan

      wait_for_print_to_finish
      update_subscribers
      log '3. Profit.'.green
    end

    def update_subscribers
      @printer.reload.update_subscribers
    end

    private

    # Polls the printer until the print is over. A paused or cancelling print is still under way: its job stays active.
    # API errors (e.g. a network blip during a long pause) are retried; the print stops being monitored after
    # MAX_POLL_FAILURES consecutive failures, rather than killing the spool thread with the job left active.
    def wait_for_print_to_finish
      @started = false
      @start_polls = 0
      failures = 0
      while failures < MAX_POLL_FAILURES
        family = poll_print
        break if family && print_over?(family)

        failures = family ? 0 : failures + 1
        sleep(WAIT_TIME)
      end
      log("Gave up monitoring the print after #{failures} failed polls".red) if failures >= MAX_POLL_FAILURES
    end

    # Whether the print is over: it was under way (printing, paused or cancelling) and no longer is. Until it starts,
    # OPERATIONAL means it hasn't started yet, for up to MAX_START_POLLS polls. Any other family (ERROR, OFFLINE, ...)
    # ends it right away.
    def print_over?(family)
      if family.in_progress?
        @started = true
        return false
      end
      return true if @started || family != PrinterStateFamily::Operational

      @start_polls += 1
      return false if @start_polls < MAX_START_POLLS

      log("The print didn't start after #{@start_polls} polls".red)
      true
    end

    # The print's state family, or nil when the printer couldn't be read. Only the first failure of a streak is logged.
    # Reads the state and the progress with a single request.
    def poll_print
      progress = @printer.api.print_progress
      @poll_failing = false
      family = progress[:state_family]
      printing_updates(progress[:progress]) if family == PrinterStateFamily::Printing
      family
    # A server that isn't OctoPrint can answer with HTML (JSON::ParserError) or without an `error` key (KeyError)
    rescue PrinterBackends::Error, JSON::ParserError, KeyError => e
      log("Could not read the print's state, retrying: #{e.class}: #{e.message}".red) unless @poll_failing
      @poll_failing = true
      nil
    end

    def printing_updates(completion)
      return if completion.nil? # e.g. while OctoPrint is still "Starting" the print

      progress = completion.ceil

      track_progress(progress)
      log("#{progress}%")
      update_subscribers
    end
  end
end
