# frozen_string_literal: true

module Mutations
  class UpdateFileNotes < Mutations::BaseMutation
    description 'Mutation to update the notes attached to a file. Supports Markdown.'

    argument :id, ID, required: true
    argument :notes,
             String,
             required: true

    field :file, Types::FileType, null: true

    def resolve(id:, notes:)
      file = FileManager::File.find(id)

      if file.update!(notes: notes)
        { file: file }
      else
        { file: nil }
      end
    end
  end
end
