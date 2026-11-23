# typed: true
# frozen_string_literal: true

module Library
  class Item
    # Replaces the content of a file (saved from the file editor, for updateFile), optionally renaming it, then
    # schedules reading its G-code summary again (Library::GcodeSummaryScheduling: the summary is pending meanwhile).
    #
    #   Library::Item::ContentChange.new(item:, content: "G28\nG1 X10\n", filename: 'cube.gcode').save!
    class ContentChange < ApplicationModel
      attribute :item
      attribute :content, :string
      # The new name, the current one when nil
      attribute :filename, :string

      validates :item, presence: true
      validate :content_given

      rescue_into_errors ActiveRecord::RecordNotSaved

      private

      #: -> void
      def persist
        attach
        # Not G-code (an .stl): nothing to schedule
        Library::GcodeSummaryScheduling.new(item:).save
      end

      #: -> void
      def attach
        attached = item.file.attach(io: temp_file, filename: filename.presence || item.filename)
        raise ActiveRecord::RecordNotSaved.new('The file could not be saved', item) unless attached
      end

      # The content, written to tmp/ under the file's name
      #: -> ::File
      def temp_file
        path = Rails.root.join("tmp/#{item.file.filename}")
        ::File.write(path, content)
        ::File.open(path)
      end

      # Empty is a content; nil isn't
      #: -> void
      def content_given
        errors.add(:content, :blank) if content.nil?
      end
    end
  end
end
