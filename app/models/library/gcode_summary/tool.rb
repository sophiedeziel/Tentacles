# typed: true
# frozen_string_literal: true

module Library
  class GcodeSummary
    # The filament one tool of a G-code file uses: `tool` is 0-based (as in T0), `material` a key of
    # Filament::MATERIALS (nil when the slicer's material isn't one of them: `material_raw` keeps it as written),
    # `colour_hex` as the slicer wrote it (never turned into a name), and how much, in grams and mm. Any value but
    # `tool` may be nil: Not known.
    #
    #   tool.material      # => "PLA"
    #   tool.material_raw  # => "PLA"; "PCTG" with material nil
    #   tool.colour_hex    # => "#FF8000"
    #
    # Named Tool, not Filament: inside Library a Filament constant would hide ::Filament.
    class Tool < ApplicationRecord
      self.table_name = 'gcode_summary_tools'

      belongs_to :gcode_summary, class_name: 'Library::GcodeSummary', inverse_of: :tools

      validates :tool, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :tool, uniqueness: { scope: :gcode_summary_id }
      validates :material, inclusion: { in: Filament::MATERIALS }, allow_nil: true
    end
  end
end
