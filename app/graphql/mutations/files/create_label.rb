# frozen_string_literal: true

module Mutations
  module Files
    class CreateLabel < Base::Mutation
      description 'Creates a label'

      argument :name, String, required: true
      argument :color, String, required: true

      field :label, Types::Label, null: true

      def resolve(name:, color:)
        label = ::Label.new(name:, color:)

        if label.save
          { label: }
        else
          { label: nil }
        end
      end
    end
  end
end
