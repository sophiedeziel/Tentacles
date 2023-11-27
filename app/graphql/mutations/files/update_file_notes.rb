# frozen_string_literal: true

module Mutations
  module Files
    class UpdateFileNotes < Base::Mutation
      description 'Mutation to update the notes attached to a file. Supports Markdown.'

      argument :id, ID, required: true
      argument :notes,
               String,
               required: true

      field :file, Types::File, null: true

      def resolve(id:, notes:)
        file = ::FileRecord.find(id)

        if file.update!(notes:)
          { file: }
        else
          { file: nil }
        end
      end
    end
  end
end
