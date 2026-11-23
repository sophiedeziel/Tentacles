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
    field :unlabelFiles, mutation: Mutations::Files::UnlabelFiles
    field :reanalyseGcode, mutation: Mutations::Files::ReanalyseGcode

    field :addPrinter, mutation: Mutations::Printers::AddPrinter
    field :enqueueFiles, mutation: Mutations::Printers::EnqueueFiles
    field :send_files_to_printers, mutation: Mutations::Printers::SendFilesToPrinters
    field :start_next_print, mutation: Mutations::Printers::StartNextPrint
    field :pausePrint, mutation: Mutations::Printers::PausePrint
    field :resumePrint, mutation: Mutations::Printers::ResumePrint
    field :cancelPrint, mutation: Mutations::Printers::CancelPrint
    field :connectPrinter, mutation: Mutations::Printers::ConnectPrinter
    field :reconnectPrinter, mutation: Mutations::Printers::ReconnectPrinter
    field :removePrinter, mutation: Mutations::Printers::RemovePrinter
    field :setPrinterFavorite, mutation: Mutations::Printers::SetPrinterFavorite
    field :updatePrinter, mutation: Mutations::Printers::UpdatePrinter
    field :requestPrinterAppKey, mutation: Mutations::Printers::RequestPrinterAppKey
    field :cancelPrinterAppKeyRequest, mutation: Mutations::Printers::CancelPrinterAppKeyRequest
    field :setLoadedFilament, mutation: Mutations::Printers::SetLoadedFilament
    field :clearLoadedFilament, mutation: Mutations::Printers::ClearLoadedFilament
    field :setPrinterTakesJobs, mutation: Mutations::Printers::SetPrinterTakesJobs

    field :addToQueue, mutation: Mutations::Queue::AddToQueue
    field :movePrintJob, mutation: Mutations::Queue::MovePrintJob
    field :holdPrintJob, mutation: Mutations::Queue::HoldPrintJob
    field :releasePrintJob, mutation: Mutations::Queue::ReleasePrintJob
    field :removePrintJob, mutation: Mutations::Queue::RemovePrintJob
    field :setPrintJobCopies, mutation: Mutations::Queue::SetPrintJobCopies
    field :updatePrintJob, mutation: Mutations::Queue::UpdatePrintJob
    field :unbindPrintJob, mutation: Mutations::Queue::UnbindPrintJob
    field :confirmBedCleared, mutation: Mutations::Queue::ConfirmBedCleared
    field :pauseDispatch, mutation: Mutations::Queue::PauseDispatch
    field :resumeDispatch, mutation: Mutations::Queue::ResumeDispatch

    field :saveDashboard, mutation: Mutations::Dashboards::SaveDashboard
  end
end
