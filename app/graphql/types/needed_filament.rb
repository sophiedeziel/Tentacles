# frozen_string_literal: true

module Types
  # A ::PrintQueue::Needs::Tool, with the colour its print job asks for
  class NeededFilament < Base::Object
    description 'The filament one tool of a print job needs. Null values are Not known (material) or Any colour.'

    field :tool, Integer, null: false, description: 'The tool, from 0 (as in T0). It uses slot tool + 1.'
    field :material, String, null: true, description: 'One of filamentMaterials, e.g. "PLA". Null when Not known'
    field :colour, String, null: true, description: "The print job's colour, e.g. \"Black\". Null for Any colour"

    def tool = object[:tool].tool
    def material = object[:tool].material
    def colour = object[:colour]
  end
end
