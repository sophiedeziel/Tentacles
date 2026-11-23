# frozen_string_literal: true

module Library
  # A file of the library: an uploaded file (G-code today), with its notes, labels and print jobs
  #
  #   item = Library::Item.create!(notes: '', file: { io:, filename: 'cube.gcode' })
  #   item.gcode_analysis.slicer # => a Gcode::Slicer::PrusaSlicer
  class Item < ApplicationRecord
    self.table_name = 'file_records'

    has_one_attached :file
    # A job can't lose its file (executable_id is NOT NULL): deleting a file deletes the jobs that print it
    has_many :jobs, class_name: 'Printer::Job', as: :executable, dependent: :delete_all

    # file_record_id keeps its name from before the Library namespace
    has_many :labelings, class_name: 'Library::Labeling', foreign_key: :file_record_id, inverse_of: :item,
                         dependent: :destroy
    has_many :labels, through: :labelings
    # What the file needs to print (G-code only), read from the file by Gcode::Summary
    has_one :gcode_summary, class_name: 'Library::GcodeSummary', foreign_key: :file_record_id, inverse_of: :item,
                            dependent: :destroy

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
      @top_file_comments ||= Gcode::Analysis.new(file).top_file_comments.join("\r\n")
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
          Gcode::Analysis.new(file)
        end
    end
  end
end
