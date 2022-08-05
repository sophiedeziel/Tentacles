# frozen_string_literal: true

module Spooler
  class Queue
    attr_reader :name, :operations

    def initialize(name)
      @name = name
      @operations = []
      @thread = Thread.new do
        loop do
          op = @operations.slice!(0)
          op.execute if op.present?
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
