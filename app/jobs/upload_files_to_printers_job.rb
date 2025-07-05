# typed: true
# frozen_string_literal: true

class UploadFilesToPrintersJob < ApplicationJob
  extend T::Sig

  # This job uploads files to multiple printers.
  # It expects file_ids and printer_ids as parameters.
  # The files are moved to a temporary location before uploading.
  queue_as :default

  def perform(file_ids, printer_ids, **)
    files = FileRecord.where(id: file_ids).map(&:file)
    printers = Printer.where(id: printer_ids)

    paths = move_files(files)

    printers.each do |printer|
      paths.each do |path|
        printer.upload(path.to_s, **)
      end
    end
  end

  private

  sig { params(files: T::Array[ActiveStorage::Attached::One]).returns(T::Array[Pathname]) }
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
