# frozen_string_literal: true

module Subscriptions
  # Pushed once by each PrintQueue.push_changed, while the global queue is on: after each queue operation commits,
  # when a copy starts or ends, after a dispatch pass that started copies, when a printer's own job changes status,
  # turns ready or goes offline, starts or stops taking jobs, has its loaded filament set or removed, or is removed.
  #
  #   TentaclesSchema.subscriptions.trigger(:queue_changed, {}, {})
  #
  # The payload is small: clients refetch globalQueue (debouncing bursts). Broadcast: the update runs once per trigger
  # and is delivered to every subscriber.
  class QueueChanged < Subscriptions::BaseSubscription
    description 'The global print queue changed: refetch globalQueue. Not pushed while the queue is off.'
    type Types::QueueChange, null: false
    broadcastable true

    # Nothing is sent on subscribe; clients load the queue with globalQueue
    def subscribe
      :no_response
    end

    # Read when it's pushed (the trigger passes nothing)
    def update
      { dispatch_paused: ::PrintQueue::Setting.dispatch_paused? }
    end
  end
end
