# typed: true
# frozen_string_literal: true

module Types
  # One validation error of a mutation, with the input field it concerns (null when it concerns no field)
  class UserError < Base::Object
    extend T::Sig

    description 'Why a mutation refused its input'

    field :field, String, null: true, description: 'The input field it concerns, e.g. "colour". Null when it ' \
                                                   'concerns none.'
    field :message, String, null: false, description: 'The message to show, e.g. "Colour can\'t be blank"'

    # The user errors of a model's errors: the attribute, in camelCase, as the field (null for :base), and the full
    # message
    #
    #   Types::UserError.from(change.errors) # => [{ field: 'colour', message: "Colour can't be blank" }]
    sig { params(errors: ActiveModel::Errors).returns(T::Array[T::Hash[Symbol, T.nilable(String)]]) }
    def self.from(errors)
      errors.map do |error|
        field = error.attribute == :base ? nil : error.attribute.to_s.camelize(:lower)
        { field:, message: error.full_message }
      end
    end

    # A user error that concerns no field
    sig { params(message: String).returns(T::Hash[Symbol, T.nilable(String)]) }
    def self.base(message)
      { field: nil, message: }
    end
  end
end
