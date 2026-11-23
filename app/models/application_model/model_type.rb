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
    #: singleton(ApplicationModel)
    attr_reader :model_class

    #: (singleton(ApplicationModel) model_class) -> void
    def initialize(model_class)
      super()
      @model_class = model_class
    end

    #: -> Symbol
    def type
      :model
    end

    #: (ApplicationModel? value) -> untyped
    def serialize(value)
      value&.as_json
    end

    #: (untyped other) -> bool
    def ==(other)
      super && other.model_class == model_class
    end

    # The attribute's type in the RBIs that `bin/tapioca dsl` generates
    #: -> T::Types::Base
    def __tapioca_type
      T::Utils.coerce(T.nilable(model_class))
    end

    private

    #: (untyped value) -> ApplicationModel
    def cast_value(value)
      case value
      when model_class then value
      when Hash then model_class.new(value.stringify_keys.slice(*model_class.attribute_names))
      else raise ArgumentError, "Can't cast #{value.class} to #{model_class}"
      end
    end
  end
end
