# typed: true
# frozen_string_literal: true

module Library
  # Reads a G-code file (Gcode::Summary) into its Library::GcodeSummary, replacing the values and the tool rows in one
  # transaction (Library::GcodeSummary::Replacement). Run in the background by AnalyseGcodeJob, scheduled by
  # Library::GcodeSummaryScheduling.
  #
  #   Library::GcodeSummaryRefresh.new(item:).save!
  #
  # - Does nothing for a row that is already current (ready, read by the current Gcode::Summary::VERSION): a job
  #   enqueued twice reads the file once.
  # - A file that isn't G-code text fails the row with a short error, without raising: reading it again won't help.
  # - A storage error raises (the job retries it), and so does anything unexpected.
  # - When the file's content changed while it was read, the values read are thrown away: the change scheduled
  #   another read.
  class GcodeSummaryRefresh < ApplicationModel
    attribute :item

    validates :item, presence: true
    validate :item_is_gcode

    # The row written, after save
    #: Library::GcodeSummary?
    attr_reader :gcode_summary

    private

    #: -> void
    def persist
      row = @gcode_summary = Library::GcodeSummary.find_or_create_for!(item)
      return if row.current?

      blob_id = item.file.blob_id
      summary = read
      row.with_lock do
        # Changed since it was read: the change rescheduled a read, and the row is pending again
        next unless content_unchanged?(blob_id)

        write(row, summary)
      end
    rescue ActiveRecord::RecordNotFound
      # The file was deleted while it was read, and its summary with it
    end

    # The values read, or the failure
    #: (Library::GcodeSummary row, (Gcode::Summary | String) summary) -> void
    def write(row, summary)
      if summary.is_a?(Gcode::Summary)
        Library::GcodeSummary::Replacement.new(gcode_summary: row, summary:).save!
      else
        Library::GcodeSummary::Failure.new(gcode_summary: row, message: summary).save!
      end
    end

    #: (untyped blob_id) -> bool
    def content_unchanged?(blob_id)
      ActiveStorage::Attachment.where(record_type: 'Library::Item', record_id: item.id, name: 'file')
                               .pick(:blob_id) == blob_id
    end

    # The summary read, or the error to show when the file isn't G-code text
    #: -> (Gcode::Summary | String)
    def read
      Gcode::Summary.read_file(item.file)
    rescue Gcode::Summary::Unreadable => e
      e.message
    end

    #: -> void
    def item_is_gcode
      errors.add(:item, 'is not a G-code file') if item && !item.gcode?
    end
  end
end
