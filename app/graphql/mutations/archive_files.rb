# frozen_string_literal: true

module Mutations
  class ArchiveFiles < Mutations::BaseMutation
    description 'Mutation to archive multiple files'

    argument :file_ids,
             [ID],
             required: true

    field :success, :boolean, null: false

    def resolve(file_ids:)
      files = FileManager::File.where(id: file_ids)

      files.each(&:archive)
      { success: true }
    rescue StandardError
      { file: nil }
    end
  end
end
