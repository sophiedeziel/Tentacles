# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :archiveFiles, mutation: Mutations::ArchiveFiles
    field :addPrinter, mutation: Mutations::AddPrinter
    field :enqueueFiles, mutation: Mutations::EnqueueFiles
    field :send_files_to_printers, mutation: Mutations::SendFilesToPrinters
    field :start_next_print, mutation: Mutations::StartNextPrint
    field :unarchiveFiles, mutation: Mutations::UnarchiveFiles
    field :uploadFile, mutation: Mutations::UploadFile
    field :updateFile, mutation: Mutations::UpdateFile
    field :updateFileNotes, mutation: Mutations::UpdateFileNotes
  end
end
