# frozen_string_literal: true

module Base
  class InputObject < GraphQL::Schema::InputObject
    argument_class Base::Argument
  end
end
