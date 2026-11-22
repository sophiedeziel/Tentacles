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
    extend T::Sig

    # The Ruby class of the elements of each element type, for the RBIs that `bin/tapioca dsl` generates
    ELEMENT_CLASSES = T.let({ string: String, integer: Integer, float: Float, boolean: T::Boolean }.freeze,
                            T::Hash[Symbol, T.untyped])

    sig { returns(ActiveModel::Type::Value) }
    attr_reader :element_type

    sig { params(element_type: Symbol).void }
    def initialize(element_type)
      super()
      @element_type = ActiveModel::Type.lookup(element_type)
    end

    sig { returns(Symbol) }
    def type
      :array
    end

    sig { params(value: T.nilable(T::Array[T.untyped])).returns(T.nilable(T::Array[T.untyped])) }
    def serialize(value)
      value&.map { |element| element_type.serialize(element) }
    end

    sig { params(other: T.untyped).returns(T::Boolean) }
    def ==(other)
      super && other.element_type == element_type
    end

    # The attribute's type in the RBIs that `bin/tapioca dsl` generates
    sig { returns(T::Types::Base) }
    def __tapioca_type
      T::Utils.coerce(T.nilable(T::Array[ELEMENT_CLASSES.fetch(element_type.type, T.untyped)]))
    end

    private

    sig { params(value: T.untyped).returns(T::Array[T.untyped]) }
    def cast_value(value)
      Array(value).map { |element| element_type.cast(element) }
    end
  end
end
