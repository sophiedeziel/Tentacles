# typed: true
# frozen_string_literal: true

module PrinterMonitor
  # Writes the monitor's heartbeat (see PrinterStatusStore.monitor_healthy?). Never raises: only the first failure
  # of a streak is logged, so a Redis outage doesn't flood the logs.
  class Heartbeat
    extend T::Sig

    sig { void }
    def initialize
      @failing = T.let(false, T::Boolean)
    end

    sig { void }
    def beat
      PrinterStatusStore.beat!
      @failing = false
    rescue StandardError => e
      Rails.logger.error("[PrinterMonitor] Failed to write the heartbeat: #{e.class}: #{e.message}") unless @failing
      @failing = true
    end
  end
end
