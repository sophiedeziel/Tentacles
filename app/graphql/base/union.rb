# frozen_string_literal: true

module Base
  class Union < GraphQL::Schema::Union
    edge_type_class(Base::Edge)
    connection_type_class(Base::Connection)
  end
end
