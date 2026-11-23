# frozen_string_literal: true

module Types
  # A ::Library::GcodeSummary: read from the database, never from the file (unlike GcodeAnalysis), so that a list of
  # files can select it
  class GcodeSummary < Base::Object
    description 'What a G-code file needs to print, read once in the background. Null values are Not known.'

    field :status, Types::GcodeSummaryStatus, null: false
    field :analysed_at, GraphQL::Types::ISO8601DateTime, null: true, description: 'When the file was last read'
    field :error, String, null: true, description: 'Why it could not be read, when FAILED'
    field :slicer, String, null: true, description: '"PrusaSlicer" or "Cura": the slicers whose values are read'
    field :slicer_version, String, null: true
    field :print_seconds, Integer, null: true, description: "The slicer's estimate"
    field :filament_grams, Float, null: true, description: 'The sum over the tools, null when any is Not known'
    field :filament_metres, Float, null: true, description: 'The sum over the tools, null when any is Not known'
    field :footprint, Types::GcodeFootprint, null: true, description: 'Null when no box is known'
    field :tool_count, Integer, null: true, description: 'The number of tools that extrude'
    field :tool_changes, Integer, null: true, description: 'The changes of tool, the first selection excluded'
    field :tools, [Types::GcodeTool], null: false, description: 'One per tool that extrudes or uses filament'
    field :filament_changes, [Types::GcodeFilamentChange], null: false, description: 'One per M600, in file order'

    def filament_metres = object.filament_millimetres&./(1000)

    delegate :footprint, to: :object
  end
end
