# frozen_string_literal: true

module Mutations
  class UpdateFile < Mutations::BaseMutation
    description 'Mutation to update a file\'s content'

    argument :id, ID, required: true
    argument :file_content,
             String,
             required: true

    field :file, Types::File, null: true

    def resolve(id:, file_content:)
      file = ::FileManager::File.find(id)

      if file.change_file_content!(file_content)
        { file: }
      else
        { file: nil }
      end
    end
  end
end
