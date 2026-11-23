# typed: true
# frozen_string_literal: true

module PrintQueue
  # Asks the spooler for a dispatch pass: publishes `{ "command": "dispatch" }` on the `printers` Redis channel (the
  # channel of Printer#notify_spooler, without a printer_id). The queue operations that can make a printer eligible
  # send it once their change is committed.
  #
  #   PrintQueue::DispatchRequest.new.save # => true, even when Redis is down
  #
  # Best effort: the queue change it follows is committed already, so a Redis error is logged, never raised, and the
  # spooler's periodic sweep (PrintQueue::Sweep) catches up. Does nothing while the global queue is off.
  class DispatchRequest < ApplicationModel
    private

    #: -> void
    def persist
      return unless PrintQueue.enabled?

      message = { command: Printer::SpoolerCommand::Dispatch.serialize }.to_json
      REDIS_POOL.with { |conn| conn.publish('printers', message) }
    rescue Redis::BaseError, ConnectionPool::TimeoutError => e
      Rails.logger.error("[PrintQueue::DispatchRequest] Could not publish dispatch: #{e.class}: #{e.message}")
    end
  end
end
