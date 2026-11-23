# typed: true
# frozen_string_literal: true

class ApplicationModel
  # The attribute type of an array whose elements all have another attribute type, cast (and serialized) one by one:
  #
  #   attribute :materials, ArrayType.new(:string)
  #
  #   specs.materials = ['PLA', :PETG]   # => ["PLA", "PETG"]
  #   specs.materials = 'PLA'            # => ["PLA"]
  #   specs.materials = nil              # => nil (not [], unless the attribute has `default: -> { [] }`)
  #   type.serialize(specs.materials)    # => ["PLA", "PETG"]
  class ArrayType < ActiveModel::Type::Value
    # The Ruby class of the elements of each element type, for the RBIs that `bin/tapioca dsl` generates
    ELEMENT_CLASSES = {
      string: String, integer: Integer, float: Float, boolean: T::Boolean
    }.freeze #: Hash[Symbol, untyped]

    #: ActiveModel::Type::Value
    attr_reader :element_type

    #: (Symbol element_type) -> void
    def initialize(element_type)
      super()
      @element_type = ActiveModel::Type.lookup(element_type)
    end

    #: -> Symbol
    def type
      :array
    end

    #: (Array[untyped]? value) -> Array[untyped]?
    def serialize(value)
      value&.map { |element| element_type.serialize(element) }
    end

    #: (untyped other) -> bool
    def ==(other)
      super && other.element_type == element_type
    end

    # The attribute's type in the RBIs that `bin/tapioca dsl` generates
    #: -> T::Types::Base
    def __tapioca_type
      T::Utils.coerce(T.nilable(T::Array[ELEMENT_CLASSES.fetch(element_type.type, T.untyped)]))
    end

    private

    #: (untyped value) -> Array[untyped]
    def cast_value(value)
      Array(value).map { |element| element_type.cast(element) }
    end
  end
end
