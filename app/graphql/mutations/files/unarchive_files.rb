# frozen_string_literal: true

module Mutations
  module Files
    class UnarchiveFiles < Base::Mutation
      description 'Mutation to unarchive multiple files'

      argument :file_ids,
               [ID],
               required: true

      field :success, Boolean, null: false

      def resolve(file_ids:)
        files = ::FileRecord.where(id: file_ids)

        files.each(&:unarchive)
        { success: true }
      rescue StandardError
        { success: false }
      end
    end
  end
end
