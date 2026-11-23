# frozen_string_literal: true

module Types
  class GcodeFootprint < Base::Object
    description 'The box a G-code file prints in, in mm: its extruding moves (skirt, brim and prime line ' \
                'included), or the box its slicer states'

    field :width, Float, null: false, description: 'Along X: maxX - minX'
    field :depth, Float, null: false, description: 'Along Y: maxY - minY'
    field :height, Float, null: true, description: 'The highest extruding move, null when Not known'
    field :min_x, Float, null: false
    field :max_x, Float, null: false
    field :min_y, Float, null: false
    field :max_y, Float, null: false
    field :source, String, null: false, description: '"slicer" (stated by the slicer) or "moves" (computed)'
  end
end
