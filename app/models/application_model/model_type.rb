# typed: true
# frozen_string_literal: true

class ApplicationModel
  # The attribute type of a nested model (a value object such as Printer::Status::Temperature), built from a hash and
  # serialized (to JSON, by the type's #serialize) as the model's #as_json:
  #
  #   attribute :hotend, ModelType.new(Temperature)
  #
  #   status.hotend = { 'actual' => 210.3 } # => Temperature (keys that aren't attributes are ignored)
  #   type.serialize(status.hotend)         # => { "actual" => 210.3, "target" => nil, "unit" => "CELSIUS" }
  class ModelType < ActiveModel::Type::Value
    extend T::Sig

    sig { returns(T.class_of(ApplicationModel)) }
    attr_reader :model_class

    sig { params(model_class: T.class_of(ApplicationModel)).void }
    def initialize(model_class)
      super()
      @model_class = model_class
    end

    sig { returns(Symbol) }
    def type
      :model
    end

    sig { params(value: T.nilable(ApplicationModel)).returns(T.untyped) }
    def serialize(value)
      value&.as_json
    end

    sig { params(other: T.untyped).returns(T::Boolean) }
    def ==(other)
      super && other.model_class == model_class
    end

    # The attribute's type in the RBIs that `bin/tapioca dsl` generates
    sig { returns(T::Types::Base) }
    def __tapioca_type
      T::Utils.coerce(T.nilable(model_class))
    end

    private

    sig { params(value: T.untyped).returns(ApplicationModel) }
    def cast_value(value)
      case value
      when model_class then value
      when Hash then model_class.new(value.stringify_keys.slice(*model_class.attribute_names))
      else raise ArgumentError, "Can't cast #{value.class} to #{model_class}"
      end
    end
  end
end
