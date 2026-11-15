# frozen_string_literal: true

module RootOperations
  class Subscription < GraphQL::Schema::Object
    field :printerSubscription, subscription: Subscriptions::PrinterSubscription
    field :printer_status_changed, subscription: Subscriptions::PrinterStatusChanged
    field :dashboard_changed, subscription: Subscriptions::DashboardChanged
  end
end
