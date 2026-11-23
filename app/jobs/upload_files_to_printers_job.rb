# typed: true
# frozen_string_literal: true

class UploadFilesToPrintersJob < ApplicationJob
  # This job uploads files to multiple printers, through each printer's API adapter (see Printer::Upload).
  # It expects file_ids and printer_ids as parameters, and `print: true` to start printing the files once uploaded.
  # The files are moved to a temporary location before uploading.
  queue_as :default

  # IDs are strings when they come from GraphQL
  #: (
  #|   Array[(Integer | String)] file_ids,
  #|   Array[(Integer | String)] printer_ids,
  #|   ?print: bool
  #| ) -> void
  def perform(file_ids, printer_ids, print: false)
    files = Library::Item.where(id: file_ids).map(&:file)
    printers = Printer.where(id: printer_ids)

    paths = move_files(files)

    printers.each do |printer|
      paths.each do |path|
        Printer::Upload.new(printer:, path: path.to_s, print:).save!
      end
    end
  end

  private

  #: (Array[ActiveStorage::Attached::One] files) -> Array[Pathname]
  def move_files(files)
    files.map do |file|
      T.unsafe(file).blob.open do |temp_file|
        temp_filename = Rails.root.join("tmp/#{T.unsafe(file).filename}")
        FileUtils.copy(temp_file.path, temp_filename)
        temp_filename
      end
    end
  end
end
