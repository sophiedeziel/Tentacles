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
            @current_operation&.interrupt
          end
        end
      end
    end

    def operations_loop
      loop do
        if @active && (job = @printer.next_job)
          start_and_monitor(job)
        else
          Thread.pass
        end
      end
    end

    def start_and_monitor(job)
      type = {
        'FileManager::File' => Print
      }[job.executable_type]

      @current_operation = type.new(@printer, job)
      job.update(status: 'active')
      @current_operation.update_subscribers

      @current_operation.execute
      @active = @start_job_after_finish
      job.update(status: 'completed')
      @current_operation.update_subscribers
      @current_operation = nil
    end
  end
end
