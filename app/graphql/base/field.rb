# frozen_string_literal: true

module Base
  class Field < GraphQL::Schema::Field
    argument_class Base::Argument
  end
end
