# frozen_string_literal: true

class FileRecord < ApplicationRecord
  has_one_attached :file
  has_many :jobs, class_name: 'Printer::Job', as: :executable, dependent: :nullify

  validates :file, presence: true

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

  def archived?
    !is_not_archived?
  end

  def deleted?
    false
  end

  def download_url
    Rails.application.routes.url_helpers.url_for(file)
  end

  def top_file_comments
    @top_file_comments ||= GcodeAnalysis.new(file).top_file_comments.join("\r\n")
  end

  def file_content
    file.blob.download
  end

  def change_file_content!(content, new_filename: nil)
    temp_filename = Rails.root.join("tmp/#{file.filename}")
    ::File.write(temp_filename, content)
    file.attach(io: ::File.open(temp_filename), filename: new_filename || filename)
  end

  def gcode_analysis
    @gcode_analysis ||=
      Rails.cache.fetch("#{cache_key_with_version}/gcode_analysis") do
        GcodeAnalysis.new(file)
      end
  end
end
