# typed: true
# frozen_string_literal: true

module Library
  class GcodeSummary
    # Marks a Library::GcodeSummary failed, with a short message to show, and clears its values and tools: they were
    # read from content the file no longer has, or from nothing. A Replacement by an empty Gcode::Summary. Saved by
    # Library::GcodeSummaryRefresh (a file that isn't G-code text) and AnalyseGcodeJob (storage or unexpected errors).
    #
    #   Library::GcodeSummary::Failure.new(gcode_summary:, message: 'Could not read the file from storage').save!
    class Failure < Replacement
      attribute :message, :string
      # Nothing known
      attribute :summary, default: -> { Gcode::Summary.new }

      validates :message, presence: true

      private

      # @override
      #: -> Hash[Symbol, untyped]
      def outcome = { status: 'failed', error: message.to_s.truncate(255) }
    end
  end
end
