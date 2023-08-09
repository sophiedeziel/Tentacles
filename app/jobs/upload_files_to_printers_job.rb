# frozen_string_literal: true

class UploadFilesToPrintersJob < ApplicationJob
  queue_as :default

  def perform(file_ids, printer_ids, **)
    files = FileManager::File.where(id: file_ids).map(&:file)
    printers = Printer.where(id: printer_ids)

    paths = move_files(files)

    printers.each do |printer|
      paths.each do |path|
        printer.upload(path, **)
      end
    end
  end

  private

  def move_files(files)
    files.map do |file|
      file.blob.open do |temp_file|
        temp_filename = Rails.root.join("tmp/#{file.filename}")
        FileUtils.copy(temp_file.path, temp_filename)
        temp_filename
      end
    end
  end
end
