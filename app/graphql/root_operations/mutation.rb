# frozen_string_literal: true

module RootOperations
  class Mutation < Base::Object
    field :archiveFiles, mutation: Mutations::Files::ArchiveFiles
    field :unarchiveFiles, mutation: Mutations::Files::UnarchiveFiles
    field :uploadFile, mutation: Mutations::Files::UploadFile
    field :updateFile, mutation: Mutations::Files::UpdateFile
    field :updateFileNotes, mutation: Mutations::Files::UpdateFileNotes
    field :createLabel, mutation: Mutations::Files::CreateLabel
    field :labelFiles, mutation: Mutations::Files::LabelFiles

    field :addPrinter, mutation: Mutations::Printers::AddPrinter
    field :enqueueFiles, mutation: Mutations::Printers::EnqueueFiles
    field :send_files_to_printers, mutation: Mutations::Printers::SendFilesToPrinters
    field :start_next_print, mutation: Mutations::Printers::StartNextPrint
  end
end
