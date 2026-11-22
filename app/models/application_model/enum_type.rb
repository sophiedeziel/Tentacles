# typed: true
# frozen_string_literal: true

class ApplicationModel
  # The attribute type of a T::Enum, kept as the enum and serialized (to JSON, by the type's #serialize) as its value:
  #
  #   attribute :state_family, EnumType.new(Printer::StateFamily)
  #
  #   status.state_family = 'PRINTING'         # => Printer::StateFamily::Printing
  #   status.state_family = 'PRINTNG'          # raises KeyError once read (casts are lazy), like T::Struct did
  #   type.serialize(Printer::StateFamily::Paused) # => "PAUSED"
  class EnumType < ActiveModel::Type::Value
    extend T::Sig

    sig { returns(T.class_of(T::Enum)) }
    attr_reader :enum_class

    sig { params(enum_class: T.class_of(T::Enum)).void }
    def initialize(enum_class)
      super()
      @enum_class = enum_class
    end

    sig { returns(Symbol) }
    def type
      :enum
    end

    sig { params(value: T.nilable(T::Enum)).returns(T.untyped) }
    def serialize(value)
      value&.serialize
    end

    sig { params(other: T.untyped).returns(T::Boolean) }
    def ==(other)
      super && other.enum_class == enum_class
    end

    # The attribute's type in the RBIs that `bin/tapioca dsl` generates
    sig { returns(T::Types::Base) }
    def __tapioca_type
      T::Utils.coerce(T.nilable(enum_class))
    end

    private

    sig { params(value: T.untyped).returns(T::Enum) }
    def cast_value(value)
      value.is_a?(enum_class) ? value : enum_class.deserialize(value)
    end
  end
end
