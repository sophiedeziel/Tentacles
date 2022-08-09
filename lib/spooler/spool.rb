# frozen_string_literal: true

class Spooler
  class Spool
    attr_reader :name, :operations

    def initialize(printer)
      @printer = printer
      @operations = []
      @thread = start_thread
      @current_operation = nil
      @active = true
      @start_job_after_finish = false
    end

    def working?
      @operations.any?
    end

    def enqueue(type, *args)
      operation = type.new(@printer, *args)
      @operations << operation
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
        if @active && @operations.any?
          @current_operation = @operations.slice!(0)
          @current_operation.execute
          @active = @start_job_after_finish
        else
          Thread.pass
        end
      end
    end
  end
end
