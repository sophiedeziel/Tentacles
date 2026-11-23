# frozen_string_literal: true

module Types
  # A ::PrintQueue::Needs
  class PrintJobNeeds < Base::Object
    description "What a print job needs from a printer, read from its file's G-code summary and its colour. Null " \
                'values are Not known.'

    field :pending, Boolean, null: false, resolver_method: :pending?,
                             description: 'Whether the G-code summary is not read yet: the job waits until it is'
    field :known, Boolean, null: false, method: :known?,
                           description: 'Whether the summary was read. False when it failed or the file is not ' \
                                        'G-code: every value is Not known and no printer is refused for it.'
    field :colour, String, null: true, description: 'The colour asked for, null for Any colour'
    field :filaments, [Types::NeededFilament], null: false,
                                               description: 'One per tool the file uses, in tool order: empty when ' \
                                                            'no tool is known'
    field :footprint, Types::GcodeFootprint, null: true, description: 'The box it prints in, null when Not known'
    field :height, Float, null: true, description: 'The highest extruding move, in mm'
    field :tool_count, Integer, null: true, description: 'The number of tools that extrude'

    def pending? = !object.runnable?
    def filaments = object.tools.map { |tool| { tool:, colour: object.colour } }
  end
end
