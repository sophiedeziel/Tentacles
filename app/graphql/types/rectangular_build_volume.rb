# frozen_string_literal: true

module Types
  class RectangularBuildVolume < Base::Object
    description 'The build volume of a printer with a rectangular bed, in mm'
    default_broadcastable true

    field :x, Float, null: false, description: 'Width, in mm'
    field :y, Float, null: false, description: 'Depth, in mm'
    field :z, Float, null: false, description: 'Height, in mm'
  end
end
