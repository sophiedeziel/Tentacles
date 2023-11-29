# frozen_string_literal: true

class FileRecord
  class GcodeAnalysis
    class Cura < Slicer
      HUMAN_NAME = 'Cura'
      LAYER_CHANGE = /\ALAYER:(.+)/
      COMMENT_WATCHERS = {
        # This logic doesn't work yet. There's some data found but it's not correct.
        # Each slice has a different comment pattern and should be handled differently.
        LAYER_CHANGE => :layer_change
      }.freeze

      def analyse_comment(comment, index)
        return if comment.blank?

        COMMENT_WATCHERS.find do |regex, method|
          send(method, comment, index) if comment.match(regex)
        end
      end

      private

      def layer_change(comment, index)
        number = comment.match(LAYER_CHANGE)[1].to_f
        layer_lines = {
          line_number: index + 1,
          id: number,
          height: nil,
          z: nil
        }
        @analysis.layers << layer_lines
      end
    end
  end
end
