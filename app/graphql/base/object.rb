# frozen_string_literal: true

module Base
  class Object < GraphQL::Schema::Object
    edge_type_class(Base::Edge)
    connection_type_class(Base::Connection)
    field_class Base::Field
  end
end
