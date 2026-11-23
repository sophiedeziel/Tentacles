# typed: true
# frozen_string_literal: true

class Printer
  module Monitor
    # The monitor's heartbeat, kept in Redis: the Supervisor and every Worker write one, and the monitor counts as
    # healthy (see the monitorHealthy query) while the last one is less than 15 seconds old.
    #
    #   Printer::Monitor::Heartbeat.create!     # beats now
    #   Printer::Monitor::Heartbeat.last&.at    # => the time of the last beat, nil without a (readable) one
    #   Printer::Monitor::Heartbeat.healthy?    # => false when it's too old, or when Redis is down
    class Heartbeat < ApplicationModel
      # The Redis key predates the Printer::Monitor namespace: kept, so a running monitor stays healthy across a deploy
      KEY = 'printer_monitor:heartbeat'
      # The monitor counts as healthy when its last heartbeat is more recent than this
      HEALTHY_WITHIN = 15.seconds #: ActiveSupport::Duration

      attribute :at, TimeType.new, default: -> { Time.current }

      validates :at, presence: true

      class << self
        # nil without a heartbeat, or with an unreadable one. Redis errors are raised.
        #: -> Printer::Monitor::Heartbeat?
        def last
          value = REDIS_POOL.with { |conn| conn.get(KEY) }
          value.present? ? new(at: Float(value)) : nil
        rescue ArgumentError, TypeError
          nil
        end

        # False when Redis can't be reached either
        #: (?now: Printer::Status::TimeLike) -> bool
        def healthy?(now: Time.current)
          at = last&.at
          !at.nil? && now - at < HEALTHY_WITHIN
        rescue Redis::BaseError => e
          Rails.logger.warn("[Printer::Monitor::Heartbeat] Could not read the monitor heartbeat: #{e.message}")
          false
        end
      end

      private

      # Stored as epoch seconds
      #: -> void
      def persist
        REDIS_POOL.with { |conn| conn.set(KEY, at.to_f.to_s) }
      end
    end
  end
end
