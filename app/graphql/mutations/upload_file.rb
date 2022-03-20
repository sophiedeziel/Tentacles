# frozen_string_literal: true

module Mutations
  class UploadFile < Mutations::BaseMutation
    description 'Mutation to upload a file'

    argument :file_attributes,
             InputObjects::UploadFileAttributes,
             required: true

    field :file, Types::FileType, null: true

    def resolve(file_attributes:)
      file = FileManager::File.new(file_attributes.to_h)
      if file.save!
        { file: file }
      else
        { file: nil }
      end
    end
  end
end
