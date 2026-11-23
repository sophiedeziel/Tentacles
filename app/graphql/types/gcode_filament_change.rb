# frozen_string_literal: true

module Types
  class GcodeFilamentChange < Base::Object
    description 'A filament change (M600) in a G-code file'

    field :line, Integer, null: false, description: 'The line of the M600, from 1'
    field :z, Float, null: true, description: 'The height it happens at, in mm. Null when Not known'
    field :layer, Integer, null: true, description: 'The layer it happens at, from 1. Null when Not known'

    def line = object['line']
    def z = object['z']
    def layer = object['layer']
  end
end
