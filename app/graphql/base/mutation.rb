# frozen_string_literal: true

module Base
  class Mutation < GraphQL::Schema::RelayClassicMutation
    argument_class Base::Argument
    field_class Base::Field
    input_object_class Base::InputObject
    object_class Base::Object
  end
end
