# typed: true
# frozen_string_literal: true

class Printer
  module Monitor
    # Runs #tick in a thread, waiting #delay seconds between ticks, until #stop is called.
    #
    # The wait is interruptible: #stop wakes the thread up right away (or after the tick in progress).
    #
    #   worker = Printer::Monitor::Worker.new(printer:).start
    #   worker.stop
    #   worker.join
    #
    # The thread and the stop signal are instance variables, not attributes: they're the runtime state of the process,
    # and only #stop (a push to a Thread::Queue, which is thread-safe) touches them from another thread.
    # @abstract
    module Runnable
      extend ActiveSupport::Concern
      include Logging

      # @abstract
      #: -> void
      def tick = super

      # Seconds to wait before the next tick
      # @abstract
      #: -> Float
      def delay = super

      #: -> self
      def start
        stop_signal
        @thread ||= Thread.new { run }
        self
      end

      #: -> void
      def stop
        stop_signal << :stop
      end

      #: (?Numeric? timeout) -> Thread?
      def join(timeout = nil)
        thread = @thread
        return nil if thread.nil?

        timeout ? thread.join(timeout) : thread.join
      end

      private

      #: -> Thread::Queue
      def stop_signal
        @stop_signal ||= Thread::Queue.new
      end

      #: -> void
      def run
        Kernel.loop do
          tick_with_executor
          break if stop_signal.pop(timeout: delay)
        end
      end

      # Wraps the tick like a request (database connections go back to the pool, ...)
      #: -> void
      def tick_with_executor
        Rails.application.executor.wrap { tick }
      rescue StandardError => e
        log_exception('Unexpected error in the monitor loop', e)
      end
    end
  end
end
