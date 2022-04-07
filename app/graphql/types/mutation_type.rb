# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :archiveFiles, mutation: Mutations::ArchiveFiles
    field :unarchiveFiles, mutation: Mutations::UnarchiveFiles
    field :uploadFile, mutation: Mutations::UploadFile
    field :updateFile, mutation: Mutations::UpdateFile
    field :updateFileNotes, mutation: Mutations::UpdateFileNotes
  end
end
