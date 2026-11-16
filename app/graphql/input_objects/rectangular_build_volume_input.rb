# frozen_string_literal: true

module InputObjects
  class RectangularBuildVolumeInput < Base::InputObject
    description 'The build volume of a rectangular bed, in mm (see RectangularBuildVolume)'

    argument :x, Float, required: true
    argument :y, Float, required: true
    argument :z, Float, required: true

    # The Printer::Specs columns: a rectangular bed has no diameter
    def to_attributes
      { bed_shape: 'rectangular', build_volume_x: x, build_volume_y: y, build_volume_z: z, build_diameter: nil }
    end
  end
end
