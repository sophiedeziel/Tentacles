# frozen_string_literal: true

module Subscriptions
  # Pushed by the printer monitor whenever a printer's status snapshot changes:
  #
  #   TentaclesSchema.subscriptions.trigger(:printer_status_changed, {}, printer)
  #
  # Broadcast: the update runs once per trigger and is delivered to every subscriber, so everything it exposes
  # must be context-independent.
  class PrinterStatusChanged < Subscriptions::BaseSubscription
    description 'A printer whose status changed'
    type Types::Printer, null: false
    broadcastable true

    # Nothing is sent on subscribe; clients load the initial state with a query
    def subscribe
      :no_response
    end

    # The printer passed to the trigger
    def update
      object
    end
  end
end
