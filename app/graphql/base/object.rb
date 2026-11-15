# frozen_string_literal: true

module Base
  class Object < GraphQL::Schema::Object
    edge_type_class(Base::Edge)
    connection_type_class(Base::Connection)
    field_class Base::Field

    class << self
      # Marks every field of this type (and its subclasses) as safe to broadcast to all subscribers, unless the
      # field sets `broadcastable:` itself. Only use it on types whose fields don't depend on the context (the
      # current user, ...). GraphQL::Subscriptions::BroadcastAnalyzer reads `default_broadcastable?`.
      #
      # See https://graphql-ruby.org/subscriptions/broadcast.html
      def default_broadcastable(value)
        @default_broadcastable = value
      end

      # true / false when set on this type or a superclass, nil otherwise (the schema's default applies)
      def default_broadcastable?
        defined?(@default_broadcastable) ? @default_broadcastable : superclass.try(:default_broadcastable?)
      end
    end
  end
end
