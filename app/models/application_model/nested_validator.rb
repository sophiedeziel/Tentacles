# typed: true
# frozen_string_literal: true

class ApplicationModel
  # Validates a nested model (a ModelType attribute) with its own validations, like ActiveRecord's
  # validates_associated. Reading it runs its cast, and validating it runs the casts of the attributes its validations
  # read: an unknown enum value raises KeyError there, as it does for the parent's own (see EnumType).
  #
  #   attribute :hotend, ModelType.new(Temperature)
  #   validates :hotend, nested: true # "Hotend is invalid" when the Temperature is; nil is valid
  class NestedValidator < ActiveModel::EachValidator
    #: (ApplicationModel record, Symbol attribute, ApplicationModel? value) -> void
    def validate_each(record, attribute, value)
      record.errors.add(attribute, :invalid) if value && !value.valid?
    end
  end
end
