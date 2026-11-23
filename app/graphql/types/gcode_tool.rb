# frozen_string_literal: true

module Types
  # A ::Library::GcodeSummary::Tool
  class GcodeTool < Base::Object
    description 'The filament one tool of a G-code file uses. Null values are Not known.'

    field :tool, Integer, null: false, description: 'The tool, from 0 (as in T0)'
    field :material, String, null: true,
                             description: 'One of filamentMaterials, e.g. "PLA". Null when the slicer wrote none, or ' \
                                          'one that is not in the list (see materialRaw)'
    field :material_raw, String, null: true, description: 'The material as the slicer wrote it, e.g. "PCTG"'
    field :colour_hex, String, null: true, description: 'The colour as the slicer wrote it, e.g. "#FF8000"'
    field :grams, Float, null: true
    field :metres, Float, null: true

    def metres = object.millimetres&./(1000)
  end
end
