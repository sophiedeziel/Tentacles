# typed: true
# frozen_string_literal: true

module PrinterMonitor
  # Runs #tick in a thread, waiting #delay seconds between ticks, until #stop is called.
  #
  # The wait is interruptible: #stop wakes the thread up right away (or after the tick in progress).
  module Runnable
    extend T::Sig
    extend T::Helpers
    include Logging

    abstract!

    sig { abstract.void }
    def tick; end

    # Seconds to wait before the next tick
    sig { abstract.returns(Float) }
    def delay; end

    sig { returns(T.self_type) }
    def start
      stop_signal
      @thread ||= Thread.new { run }
      self
    end

    sig { void }
    def stop
      stop_signal << :stop
    end

    sig { params(timeout: T.nilable(Numeric)).returns(T.nilable(Thread)) }
    def join(timeout = nil)
      thread = @thread
      return nil if thread.nil?

      timeout ? thread.join(timeout) : thread.join
    end

    private

    sig { returns(Thread::Queue) }
    def stop_signal
      @stop_signal ||= Thread::Queue.new
    end

    sig { void }
    def run
      Kernel.loop do
        tick_with_executor
        break if stop_signal.pop(timeout: delay)
      end
    end

    # Wraps the tick like a request (database connections go back to the pool, ...)
    sig { void }
    def tick_with_executor
      Rails.application.executor.wrap { tick }
    rescue StandardError => e
      log_exception('Unexpected error in the monitor loop', e)
    end
  end
end
