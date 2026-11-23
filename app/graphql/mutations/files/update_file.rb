# frozen_string_literal: true

module Mutations
  module Files
    class UpdateFile < Base::Mutation
      description 'Mutation to update a file\'s content'

      argument :id, ID, required: true
      argument :file_content,
               String,
               required: true
      argument :file_name,
               String,
               required: false

      field :file, Types::File, null: true

      def resolve(id:, file_content:, file_name: nil)
        file = ::Library::Item.find(id)

        if ::Library::Item::ContentChange.new(item: file, content: file_content, filename: file_name).save
          { file: }
        else
          { file: nil }
        end
      end
    end
  end
end
