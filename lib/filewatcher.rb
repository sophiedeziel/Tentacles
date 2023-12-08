# frozen_string_literal: true

require File.expand_path('../config/environment', __dir__)

class Filewatcher
  def run
    listener = Listen.to('tmp/auto_import') do |modified, added, removed|
      added.each do |path|
        create_file_record(path)
        delete_file(path)
      end

      Rails.logger.debug(modified:, added:, removed:)
    end
    listener.start

    sleep
  end

  private

  def create_file_record(path)
    FileRecord.create(notes: '') do |file|
      file.file.attach(io: File.open(path), filename: File.basename(path))
    end
  end

  def delete_file(path)
    File.delete(path)
  end
end
