# frozen_string_literal: true

module Mutations
  module Files
    class ArchiveFiles < Base::Mutation
      description 'Mutation to archive multiple files'

      argument :file_ids,
               [ID],
               required: true

      field :success, Boolean, null: false

      def resolve(file_ids:)
        files = ::FileRecord.where(id: file_ids)

        files.each(&:archive)
        { success: true }
      rescue StandardError
        { success: false }
      end
    end
  end
end
