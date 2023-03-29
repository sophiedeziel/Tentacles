# frozen_string_literal: true

module Base
  module Node
    include Base::Interface
    # Add the `id` field
    include GraphQL::Types::Relay::NodeBehaviors
  end
end
