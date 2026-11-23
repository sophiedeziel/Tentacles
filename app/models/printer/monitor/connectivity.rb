# typed: true
# frozen_string_literal: true

class Printer
  module Monitor
    # Tracks whether a printer's server answers: the consecutive failures (for the backoff) and the last time it
    # answered, which is saved to `printers.last_seen_at` at most once a minute, and right away when it stops answering.
    #
    #   connectivity = Printer::Monitor::Connectivity.new(printer:, interval: 2.0)
    #   connectivity.record_failure # => true: it answered on the previous tick
    #   connectivity.delay          # => 4.0, doubled after each consecutive failure
    #
    # Owned by one Worker, and only touched from its thread.
    class Connectivity < ApplicationModel
      include Logging

      MAX_BACKOFF = 30.0
      PERSIST_EVERY = 1.minute #: ActiveSupport::Duration

      attribute :printer
      # Seconds between ticks while the printer answers
      attribute :interval, :float
      # Number of consecutive ticks in which the printer couldn't be reached
      attribute :failures, :integer, default: 0
      # Number of consecutive ticks in which the status couldn't be published (e.g. Redis is down)
      attribute :publish_failures, :integer, default: 0
      # The last time the printer answered this worker
      attribute :last_success_at, TimeType.new
      # The last time saved to `printers.last_seen_at`
      attribute :persisted_at, TimeType.new

      # The attributes always have a value (the defaults, and the Worker passes the interval), but the generated RBI
      # types them as nilable: these readers say they aren't.
      #: -> Float
      def interval = super #: as !nil

      #: -> Integer
      def failures = super #: as !nil

      #: -> Integer
      def publish_failures = super #: as !nil

      #: -> void
      def record_success
        now = Time.current
        # A TimeWithZone, which is_a?(Time): the generated RBI types the time attributes as Time
        self.last_success_at = T.cast(now, Time)
        self.failures = 0
        last_persisted_at = persisted_at
        persist_last_seen if last_persisted_at.nil? || now - last_persisted_at >= PERSIST_EVERY
      end

      # Returns whether the printer just went offline (it answered on the previous tick)
      #: -> bool
      def record_failure
        went_offline = failures.zero? && !last_success_at.nil?
        self.failures += 1
        persist_last_seen if went_offline
        went_offline
      end

      #: -> void
      def record_publish_success
        self.publish_failures = 0
      end

      # Returns the number of consecutive publish failures, this one included
      #: -> Integer
      def record_publish_failure
        self.publish_failures += 1
      end

      # Seconds to wait before the next tick: the interval, doubled after each consecutive failure (up to 30 s),
      # whether the printer can't be reached or the status can't be published
      #: -> Float
      def delay
        streak = [failures, publish_failures].max
        return interval if streak.zero?

        backoff = interval * (2**[streak - 1, 10].min)
        [backoff, max_delay].min.to_f
      end

      # The last time the printer answered, from memory or (before the first success) from the database
      #: -> Printer::Status::TimeLike?
      def last_seen_at
        last_success_at || printer.last_seen_at
      end

      private

      #: -> Float
      def max_delay
        [MAX_BACKOFF, interval].max
      end

      # update_column rather than touch(:last_seen_at): touch would also bump printers.updated_at once a minute
      #: -> void
      def persist_last_seen
        seen_at = last_success_at
        return if seen_at.nil?

        printer.update_column(:last_seen_at, seen_at) # rubocop:disable Rails/SkipsModelValidations
        self.persisted_at = seen_at
      rescue ActiveRecord::ActiveRecordError => e
        log_exception('Failed to save last_seen_at', e)
      end
    end
  end
end
