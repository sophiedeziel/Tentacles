# frozen_string_literal: true

module Types
  class CircularBuildVolume < Base::Object
    description 'The build volume of a printer with a circular bed (delta printers), in mm'
    default_broadcastable true

    field :diameter, Float, null: false, description: 'Diameter of the bed, in mm'
    field :height, Float, null: false, description: 'Height, in mm'
  end
end
