# frozen_string_literal: true

class Spooler
  class Spool
    attr_reader :name

    def initialize(printer)
      @printer = printer
      @thread = start_thread
      @current_operation = nil
      @active = false
      @start_job_after_finish = false
      @discarded = false
    end

    def working?
      @current_operation.present?
    end

    def stop
      @thread.kill
      @active = false
      @thread = start_thread
    end

    def resume
      @active = true
    end

    # Stops the spool for good (its printer was removed). The operation under way isn't interrupted: nothing is sent
    # to the printer, and a print under way keeps running.
    def discard
      @discarded = true
      @active = false
      @thread.kill
    end

    private

    def log(message)
      Rails.logger.debug { "#{' ' * (15 - @printer.name.size)} [ #{@printer.name} ] : #{message}" }
    end

    def start_thread
      Thread.new do
        Rails.application.executor.wrap do
          Thread.handle_interrupt(Exception => :immediate) do
            operations_loop
          ensure
            @current_operation&.interrupt unless @discarded
          end
        end
      end
    end

    def operations_loop
      loop do
        if @active && (job = @printer.next_job)
          @current_operation = build_operation(job)
          start_and_monitor
          @active = @start_job_after_finish
          @current_operation = nil
        else
          Thread.pass
        end
      end
    end

    # A job whose file can't be sent (printer unreachable, no writable storage, ...) is marked `error` rather than
    # left active, which would block the printer's queue, and the spool thread keeps running
    def start_and_monitor
      job = @current_operation.job
      job.update(status: 'active')
      @current_operation.update_subscribers

      @current_operation.execute

      job.update(status: 'completed')
      @current_operation.update_subscribers
    rescue Printer::Backend::Error => e
      @current_operation.log("Could not start the print: #{e.class}: #{e.message}".red)
      job.update(status: 'error')
      @current_operation.update_subscribers
    end

    def build_operation(job)
      type = {
        'Library::Item' => Print
      }[job.executable_type]

      type.new(@printer, job)
    end
  end
end
