# frozen_string_literal: true

class Spooler
  class Spool
    attr_reader :name, :operations

    def initialize(name)
      @name = name
      @operations = []
      @thread = Thread.new do
        Rails.application.executor.wrap do
          loop do
            op = @operations.slice!(0)
            op.execute if op.present?
            sleep(WAIT_TIME)
          end
        end
      end
    end

    def working?
      @operations.any?
    end

    def start(operation)
      @operations << operation
    end

    def stop
      @thread.kill
    end
  end
end
