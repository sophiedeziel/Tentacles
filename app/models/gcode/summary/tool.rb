# typed: true
# frozen_string_literal: true

module Gcode
  class Summary
    # The filament one tool uses, as read from a file: stored as a Library::GcodeSummary::Tool, whose doc describes
    # each value. nil is Not known.
    #
    #   Gcode::Summary::Tool.new(tool: 0, material: 'PLA', material_raw: 'PLA', colour_hex: '#FF8000', grams: 2.63,
    #                            millimetres: 882.3)
    class Tool < ApplicationModel
      attribute :tool, :integer
      attribute :material, :string
      attribute :material_raw, :string
      attribute :colour_hex, :string
      attribute :grams, :decimal
      attribute :millimetres, :decimal

      # @override
      #: -> bool
      def readonly? = true
    end
  end
end
