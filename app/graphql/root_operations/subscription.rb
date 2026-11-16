# frozen_string_literal: true

module RootOperations
  class Subscription < GraphQL::Schema::Object
    field :printerSubscription, subscription: Subscriptions::PrinterSubscription
    field :printer_status_changed, subscription: Subscriptions::PrinterStatusChanged
    field :dashboard_changed, subscription: Subscriptions::DashboardChanged
    field :print_queue_changed, subscription: Subscriptions::PrintQueueChanged
    field :printer_app_key_changed, subscription: Subscriptions::PrinterAppKeyChanged
  end
end
