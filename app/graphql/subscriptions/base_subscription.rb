# frozen_string_literal: true

module Subscriptions
  class BaseSubscription < GraphQL::Schema::Subscription
    # Hook up base classes
    object_class Base::Object
    field_class Base::Field
    argument_class Base::Argument
  end
end
