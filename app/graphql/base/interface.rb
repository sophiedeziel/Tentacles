# frozen_string_literal: true

module Base
  module Interface
    include GraphQL::Schema::Interface

    edge_type_class(Base::Edge)
    connection_type_class(Base::Connection)

    field_class Base::Field
  end
end
