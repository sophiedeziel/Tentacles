# frozen_string_literal: true

module Types
  class SubscriptionType < GraphQL::Schema::Object
    field :printerSubscription, subscription: Subscriptions::PrinterSubscription
  end
end
