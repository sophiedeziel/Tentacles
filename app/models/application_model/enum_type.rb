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
    #: singleton(T::Enum)
    attr_reader :enum_class

    #: (singleton(T::Enum) enum_class) -> void
    def initialize(enum_class)
      super()
      @enum_class = enum_class
    end

    #: -> Symbol
    def type
      :enum
    end

    #: (T::Enum? value) -> untyped
    def serialize(value)
      value&.serialize
    end

    #: (untyped other) -> bool
    def ==(other)
      super && other.enum_class == enum_class
    end

    # The attribute's type in the RBIs that `bin/tapioca dsl` generates
    #: -> T::Types::Base
    def __tapioca_type
      T::Utils.coerce(T.nilable(enum_class))
    end

    private

    #: (untyped value) -> T::Enum
    def cast_value(value)
      value.is_a?(enum_class) ? value : enum_class.deserialize(value)
    end
  end
end
