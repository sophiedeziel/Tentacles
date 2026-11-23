# typed: true
# frozen_string_literal: true

module Library
  # Marks a file's G-code summary pending (creating it), then reads the file in the background (AnalyseGcodeJob, which
  # runs Library::GcodeSummaryRefresh). Saved once the file is stored, by whatever creates or changes it
  # (Mutations::Files::UploadFile, Library::Item::ContentChange, lib/filewatcher.rb, Mutations::Files::ReanalyseGcode,
  # Library::GcodeReanalysis): not from a callback, where the job could run before the file is uploaded.
  #
  #   Library::GcodeSummaryScheduling.new(item:).save # => false, with errors, for a file that isn't G-code
  #   item.gcode_summary.pending?                     # => true until AnalyseGcodeJob has read it
  class GcodeSummaryScheduling < ApplicationModel
    attribute :item

    validates :item, presence: true
    validate :item_is_gcode

    private

    #: -> void
    def persist
      summary = Library::GcodeSummary.find_or_create_for!(item)
      # Waits for a read in progress to commit (Library::GcodeSummaryRefresh writes under this lock), so that its
      # values, read from the content before, end pending rather than ready. An update with no change wouldn't wait
      summary.with_lock { summary.update!(status: 'pending', error: nil) }
      AnalyseGcodeJob.perform_later(item.id)
    end

    #: -> void
    def item_is_gcode
      errors.add(:base, 'Not a G-code file') if item && !item.gcode?
    end
  end
end
