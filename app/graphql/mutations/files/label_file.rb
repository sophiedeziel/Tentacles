# frozen_string_literal: true

module Mutations
  module Files
    class LabelFile < Base::Mutation
      description 'Attaches a label to a file'

      argument :file_id, ID, required: true
      argument :label_id, ID, required: true

      field :label, Types::Label, null: true
      field :file, Types::File, null: true

      def resolve(file_id:, label_id:)
        label = ::Label.find(label_id)
        file = ::FileRecord.find(file_id)

        file.labels << label if file.present? && label.present?

        file.save!
        { label:, file: }
      rescue StandardError
        { label:, file: }
      end
    end
  end
end
