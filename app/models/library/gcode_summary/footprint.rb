# typed: true
# frozen_string_literal: true

module Library
  class GcodeSummary
    # The box a G-code file prints in, in mm, from a Library::GcodeSummary's columns: its sides, its size, its height
    # (nil when Not known) and where it comes from ("slicer" or "moves").
    #
    #   footprint = gcode_summary.footprint # nil when no box is known
    #   footprint.width  # => 123.09 (max_x - min_x)
    #   footprint.height # => 15.2, or nil
    class Footprint < ApplicationModel
      attribute :min_x, :decimal
      attribute :max_x, :decimal
      attribute :min_y, :decimal
      attribute :max_y, :decimal
      attribute :height, :decimal
      attribute :source, :string

      validates :min_x, :max_x, :min_y, :max_y, presence: true

      # The footprint of a summary's box, nil when a side of it is Not known
      #: (Library::GcodeSummary gcode_summary) -> Footprint?
      def self.of(gcode_summary)
        footprint = new(min_x: gcode_summary.min_x, max_x: gcode_summary.max_x, min_y: gcode_summary.min_y,
                        max_y: gcode_summary.max_y, height: gcode_summary.max_z,
                        source: gcode_summary.footprint_source)
        footprint if footprint.valid?
      end

      # Along X
      #: -> BigDecimal
      def width = T.must(max_x) - T.must(min_x)

      # Along Y
      #: -> BigDecimal
      def depth = T.must(max_y) - T.must(min_y)

      # Read from the summary's columns: written through them
      # @override
      #: -> bool
      def readonly? = true
    end
  end
end
