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

    # The printer passed to the trigger. A removed printer can't be loaded back (the trigger is serialized with its
    # GlobalID), so Printer::Removal passes `{ removed_printer: attributes }` instead: it comes back as a read-only
    # stand-in, whose queue is empty.
    def update
      return object unless object.is_a?(Hash)

      ::Printer.new(object.with_indifferent_access.fetch(:removed_printer)).tap(&:readonly!)
    end
  end
end
