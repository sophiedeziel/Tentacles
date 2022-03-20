# frozen_string_literal: true

module FileManager
  class File < ApplicationRecord
    has_one_attached :file

    default_scope -> {where(is_not_archived: true)}

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
  end
end
