# typed: true
# frozen_string_literal: true

module PrinterMonitor
  # Tracks whether a printer's OctoPrint answers: the consecutive failures (for the backoff) and the last time it
  # answered, which is saved to `printers.last_seen_at` at most once a minute, and right away when it stops answering.
  class Connectivity
    extend T::Sig
    include Logging

    MAX_BACKOFF = 30.0
    PERSIST_EVERY = T.let(1.minute, ActiveSupport::Duration)

    sig { override.returns(Printer) }
    attr_reader :printer

    # Number of consecutive ticks in which OctoPrint couldn't be reached
    sig { returns(Integer) }
    attr_reader :failures

    # Number of consecutive ticks in which the status couldn't be published (e.g. Redis is down)
    sig { returns(Integer) }
    attr_reader :publish_failures

    sig { params(printer: Printer, interval: Float).void }
    def initialize(printer, interval:)
      @printer = printer
      @interval = interval
      @failures = T.let(0, Integer)
      @publish_failures = T.let(0, Integer)
      @last_success_at = T.let(nil, T.nilable(PrinterStatus::TimeLike))
      @persisted_at = T.let(nil, T.nilable(PrinterStatus::TimeLike))
    end

    sig { void }
    def record_success
      now = Time.current
      @last_success_at = now
      @failures = 0
      persisted_at = @persisted_at
      persist_last_seen if persisted_at.nil? || now - persisted_at >= PERSIST_EVERY
    end

    # Returns whether the printer just went offline (it answered on the previous tick)
    sig { returns(T::Boolean) }
    def record_failure
      went_offline = @failures.zero? && !@last_success_at.nil?
      @failures += 1
      persist_last_seen if went_offline
      went_offline
    end

    sig { void }
    def record_publish_success
      @publish_failures = 0
    end

    # Returns the number of consecutive publish failures, this one included
    sig { returns(Integer) }
    def record_publish_failure
      @publish_failures += 1
    end

    # Seconds to wait before the next tick: the interval, doubled after each consecutive failure (up to 30 s),
    # whether OctoPrint can't be reached or the status can't be published
    sig { returns(Float) }
    def delay
      streak = [@failures, @publish_failures].max
      return @interval if streak.zero?

      backoff = @interval * (2**[streak - 1, 10].min)
      [backoff, max_delay].min.to_f
    end

    # The last time OctoPrint answered, from memory or (before the first success) from the database
    sig { returns(T.nilable(PrinterStatus::TimeLike)) }
    def last_seen_at
      @last_success_at || printer.last_seen_at
    end

    private

    sig { returns(Float) }
    def max_delay
      [MAX_BACKOFF, @interval].max
    end

    sig { void }
    def persist_last_seen
      seen_at = @last_success_at
      return if seen_at.nil?

      printer.update_column(:last_seen_at, seen_at) # rubocop:disable Rails/SkipsModelValidations
      @persisted_at = seen_at
    rescue ActiveRecord::ActiveRecordError => e
      log_exception('Failed to save last_seen_at', e)
    end
  end
end
