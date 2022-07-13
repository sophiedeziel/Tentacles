# frozen_string_literal: true

module Spooler
  class Queue
    attr_reader :name

    def initialize(name)
      @name = name
      @thread = nil
    end

    def working?
      !!@thread
    end

    def start(operation)
      @thread =
      Thread.new do
        operation.execute
      end
    end

    def stop
      @thread.kill
    end
  end
end
