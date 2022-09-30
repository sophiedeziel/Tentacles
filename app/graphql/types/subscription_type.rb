# frozen_string_literal: true

module Types
  class SubscriptionType < GraphQL::Schema::Object
    # field :test, subscription: Subscriptions::TestSubscription
    field :printerSubscription, subscription: Subscriptions::PrinterSubscription

    # ...
  end
end
