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
      puts "#{" " * (15 - @printer.name.size) } [ #{@printer.name} ] : #{message}"
    end

    def start_thread
      Thread.new do
        Thread.handle_interrupt(Exception => :never) do
          Rails.application.executor.wrap do
            Thread.handle_interrupt(Exception => :immediate) do
              begin
                loop do
                  log @active
                  if @active && @operations.any?
                    @current_operation = @operations.slice!(0)
                    @current_operation.execute
                    @active = @start_job_after_finish
                  else
                    sleep(WAIT_TIME)
                    #puts "waiting"
                  end
                end
              ensure
                @current_operation&.interrupt
              end
            end
          end
        end
      end
    end
  end
end
