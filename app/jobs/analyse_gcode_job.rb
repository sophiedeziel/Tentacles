# typed: true
# frozen_string_literal: true

# Reads what a G-code file needs to print into its Library::GcodeSummary (Library::GcodeSummaryRefresh). Enqueued by
# Library::GcodeSummaryScheduling (on upload, on a content change, by the file watcher, by reanalyseGcode and by
# `bin/rails gcode:reanalyse`), and by db/migrate/20261122150000_enqueue_analyse_gcode.rb for the files uploaded
# before.
#
# A file that isn't G-code text fails its row without retrying. A storage error is retried; after the third attempt,
# the row fails so that it doesn't stay pending. Any other error is a bug: the row fails, and the error raises (and
# Sidekiq retries it).
class AnalyseGcodeJob < ApplicationJob
  STORAGE_ERRORS = [ActiveStorage::Error, SystemCallError].freeze

  queue_as :default

  retry_on(*STORAGE_ERRORS, wait: :polynomially_longer, attempts: 3) do |job, error|
    Rails.logger.warn("[AnalyseGcodeJob] file ##{job.arguments.first}: #{error.class}: #{error.message}")
    gcode_summary = Library::GcodeSummary.find_by(file_record_id: job.arguments.first)
    fail_summary(gcode_summary, 'Could not read the file from storage')
  end

  #: (Integer item_id) -> void
  def perform(item_id)
    # Deleted since it was enqueued, or not G-code
    item = Library::Item.find_by(id: item_id)
    return unless item&.gcode?

    Library::GcodeSummaryRefresh.new(item:).save!
  rescue *STORAGE_ERRORS
    raise
  rescue StandardError
    self.class.fail_summary(item&.gcode_summary, 'Could not analyse this file')
    raise
  end

  # Fails the summary, when there is one, so that it doesn't stay pending
  #: (Library::GcodeSummary? gcode_summary, String message) -> void
  def self.fail_summary(gcode_summary, message)
    Library::GcodeSummary::Failure.new(gcode_summary:, message:).save! if gcode_summary
  end
end
