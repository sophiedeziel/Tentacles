# frozen_string_literal: true

module Base
  class Edge < Base::Object
    # add `node` and `cursor` fields, as well as `node_type(...)` override
    include GraphQL::Types::Relay::EdgeBehaviors
  end
end
