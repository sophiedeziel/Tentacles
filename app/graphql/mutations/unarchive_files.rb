# frozen_string_literal: true

module Mutations
  class UnarchiveFiles < Mutations::BaseMutation
    description 'Mutation to unarchive multiple files'

    argument :file_ids,
             [ID],
             required: true

    field :success, Boolean, null: false

    def resolve(file_ids:)
      files = ::FileManager::File.where(id: file_ids)

      files.each(&:unarchive)
      { success: true }
    rescue StandardError
      { success: false }
    end
  end
end
