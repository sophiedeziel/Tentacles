# typed: true
# frozen_string_literal: true

module Library
  class GcodeSummary
    # Replaces the values and the tool rows of a Library::GcodeSummary with the ones read (a Gcode::Summary), in one
    # transaction, and marks it ready, read by the current Gcode::Summary::VERSION. Saved by
    # Library::GcodeSummaryRefresh.
    #
    #   Library::GcodeSummary::Replacement.new(gcode_summary:, summary: Gcode::Summary.read_file(item.file)).save!
    class Replacement < ApplicationModel
      attribute :gcode_summary
      # A Gcode::Summary
      attribute :summary

      validates :gcode_summary, :summary, presence: true

      private

      #: -> void
      def persist
        gcode_summary.transaction do
          gcode_summary.update!(**summary.attributes.except('tools').symbolize_keys, **outcome,
                                analysis_version: Gcode::Summary::VERSION, analysed_at: Time.current)
          replace_tools
        end
      end

      #: -> Hash[Symbol, untyped]
      def outcome = { status: 'ready', error: nil }

      #: -> void
      def replace_tools
        gcode_summary.tools.delete_all
        now = Time.current
        rows = summary.tools.map do |tool|
          tool.attributes.merge('gcode_summary_id' => gcode_summary.id, 'created_at' => now, 'updated_at' => now)
        end
        # Values read by Gcode::Summary, which keeps them within the columns
        Tool.insert_all!(rows) if rows.any? # rubocop:disable Rails/SkipsModelValidations
        gcode_summary.tools.reset
      end
    end
  end
end
