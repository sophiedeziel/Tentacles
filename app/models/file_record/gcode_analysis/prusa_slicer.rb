# frozen_string_literal: true

class FileRecord
  class GcodeAnalysis
    class PrusaSlicer < Slicer
      HUMAN_NAME = 'PrusaSlicer'
      LAYER_CHANGE = /\ALAYER_CHANGE/
      LAYER_CHANGE_Z_HEIGHT = /\AZ:(.+)/
      LAYER_CHANGE_HEIGHT = /\AHEIGHT:(.+)/
      AFTER_CHANGE = /\AAFTER_LAYER_CHANGE/

      COMMENT_WATCHERS = {
        # This logic doesn't work yet. There's some data found but it's not correct.
        # Each slice has a different comment pattern and should be handled differently.
        LAYER_CHANGE => :start_layer_change,
        LAYER_CHANGE_Z_HEIGHT => :layer_change_z_height,
        LAYER_CHANGE_HEIGHT => :layer_change_height,
        AFTER_CHANGE => :layer_change
      }.freeze

      def analyse_comment(comment, index)
        return if comment.blank?

        COMMENT_WATCHERS.find do |regex, method|
          send(method, comment, index) if comment.match(regex)
        end
      end

      private

      def start_layer_change(_comment, index)
        @layer_lines = { line_number: index + 1, id: @analysis.layers.count + 1, height: nil, z: nil }
      end

      def layer_change_z_height(comment, _index)
        layer_lines[:z] = comment.match(LAYER_CHANGE_Z_HEIGHT)[1].to_f
      end

      def layer_change_height(comment, _index)
        layer_lines[:height] = comment.match(LAYER_CHANGE_HEIGHT)[1].to_f
      end

      def layer_change(_comment, _index)
        @analysis.layers << layer_lines
      end

      def layer_lines
        @layer_lines ||= {}
      end
    end
  end
end
