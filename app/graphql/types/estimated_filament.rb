# frozen_string_literal: true

module Types
  # A ::PrintQueue::Estimate::FilamentUse
  class EstimatedFilament < Base::Object
    description 'The filament one tool uses for all the copies to print. Null values are Not known (or Any colour).'

    field :tool, Integer, null: false, description: 'The tool, from 0 (as in T0)'
    field :material, String, null: true,
                             description: 'The material asked for, or the one its G-code says. Null when Not known'
    field :colour, String, null: true, description: 'The colour asked for. Null for Any colour'
    field :grams, Float, null: true
    field :metres, Float, null: true

    def metres = object.millimetres&./(1000)
  end
end
