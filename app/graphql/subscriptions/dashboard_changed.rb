# frozen_string_literal: true

module Subscriptions
  # Pushed after each saveDashboard:
  #
  #   TentaclesSchema.subscriptions.trigger(:dashboard_changed, {}, {})
  #
  # Broadcast: the update runs once per trigger and is delivered to every subscriber.
  class DashboardChanged < Subscriptions::BaseSubscription
    description 'The dashboard layout, after each save'
    type Types::Dashboard, null: false
    broadcastable true

    # Nothing is sent on subscribe; clients load the layout with the dashboard query
    def subscribe
      :no_response
    end

    # Reads the saved layout (the trigger passes nothing: the layout isn't one record)
    def update
      Types::Dashboard.saved
    end
  end
end
