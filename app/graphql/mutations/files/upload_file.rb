# frozen_string_literal: true

module Mutations
  module Files
    class UploadFile < Base::Mutation
      description 'Mutation to upload a file'

      argument :file_attributes,
               InputObjects::UploadFileAttributes,
               required: true

      field :file, Types::File, null: true

      def resolve(file_attributes:)
        file = ::FileRecord.new(file_attributes.to_h)
        if file.save!
          { file: }
        else
          { file: nil }
        end
      end
    end
  end
end
