# frozen_string_literal: true

module FileManager
  class File < ApplicationRecord
    has_one_attached :file

    def filename
      file.filename.to_s
    end

    def filetype
      ".#{filename.split('.').last}"
    end

    def filesize
      file.blob.byte_size
    end

    def archive
      update(is_not_archived: false, archived_at: Time.current)
    end

    def unarchive
      update(is_not_archived: true, archived_at: nil)
    end

    def top_file_comments
      top_comments = []
      file.blob.open do |file|
        file.each do |line|
          line.strip!
          return top_comments.join("\r\n") unless line.empty? || line.starts_with?(';')

          top_comments << line
        end
      end
      top_comments.join("\r\n")
    end

    def file_content
      file.blob.download
    end
  end
end
