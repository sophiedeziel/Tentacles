# typed: true
# frozen_string_literal: true

module Library
  # Schedules reading again (Library::GcodeSummaryScheduling) the G-code files never read, still pending (their job
  # was lost), or read by an older Gcode::Summary::VERSION: `bin/rails gcode:reanalyse`, after the version is bumped.
  #
  #   reanalysis = Library::GcodeReanalysis.new
  #   reanalysis.save!
  #   reanalysis.count # => 12, the files scheduled
  class GcodeReanalysis < ApplicationModel
    # How many files #save scheduled
    #: -> Integer
    def count = @count || 0

    private

    #: -> void
    def persist
      @count = outdated.with_attached_file.find_each.count do |item|
        Library::GcodeSummaryScheduling.new(item:).save
      end #: Integer?
    end

    # Every file, G-code or not: the filename is on the blob
    #: -> untyped
    def outdated
      with_summary = Library::Item.left_joins(:gcode_summary)
      with_summary.where(gcode_summaries: { id: nil })
                  .or(with_summary.where(gcode_summaries: { status: 'pending' }))
                  .or(with_summary.where(gcode_summaries: { analysis_version: ...Gcode::Summary::VERSION }))
    end
  end
end
