# frozen_string_literal: true

class FileRecord
  class GcodeAnalysis
    class Slicer
      # self.abstract_class = true

      COMMENT_PATTERNS = {
        Cura => /Generated with Cura_SteamEngine(.*)/,
        PrusaSlicer => /generated by PrusaSlicer(.*)/
      }.freeze

      def initialize(analysis)
        @analysis = analysis
      end

      def self.detect(analysis)
        analysis.top_file_comments.find do |comment|
          COMMENT_PATTERNS.find do |slicer, regex|
            return slicer.new(analysis) if comment.match(regex)
          end
        end
      end

      def analyse_comment(comment, index)
        # Not implemented
      end
    end
  end
end
