# frozen_string_literal: true

module RootOperations
  class Subscription < GraphQL::Schema::Object
    field :printerSubscription, subscription: Subscriptions::PrinterSubscription
  end
end
