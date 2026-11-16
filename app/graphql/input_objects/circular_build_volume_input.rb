# frozen_string_literal: true

module InputObjects
  class CircularBuildVolumeInput < Base::InputObject
    description 'The build volume of a circular (delta) bed, in mm (see CircularBuildVolume)'

    argument :diameter, Float, required: true
    argument :height, Float, required: true

    # The Printer::Specs columns: a circular bed has no X and Y
    def to_attributes
      { bed_shape: 'circular', build_diameter: diameter, build_volume_z: height, build_volume_x: nil,
        build_volume_y: nil }
    end
  end
end
