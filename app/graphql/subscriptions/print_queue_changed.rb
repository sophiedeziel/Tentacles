# frozen_string_literal: true

module Subscriptions
  # Pushed after a job is enqueued, removed, or changes status (not on progress updates), with the job's printer:
  #
  #   TentaclesSchema.subscriptions.trigger(:print_queue_changed, {}, printer)
  #
  # The printer's queue fields (queuedCount, nextJob, canStartNext) come with the push; clients reload the queue
  # lists themselves. Broadcast: the update runs once per trigger and is delivered to every subscriber.
  class PrintQueueChanged < Subscriptions::BaseSubscription
    description 'The printer of a job that was enqueued, removed, or changed status'
    type Types::Printer, null: false
    broadcastable true

    # Nothing is sent on subscribe; clients load the queue with a query
    def subscribe
      :no_response
    end

    # The printer passed to the trigger
    def update
      object
    end
  end
end
