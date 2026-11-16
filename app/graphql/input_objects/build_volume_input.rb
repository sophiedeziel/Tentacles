# frozen_string_literal: true

module InputObjects
  class BuildVolumeInput < Base::InputObject
    description 'Exactly one of: the build volume of a rectangular bed, or of a circular (delta) bed'

    one_of

    argument :rectangular, InputObjects::RectangularBuildVolumeInput, required: false
    argument :circular, InputObjects::CircularBuildVolumeInput, required: false

    # Every build volume column and the bed shape: the given shape's dimensions, the other shape's cleared
    def to_attributes
      (rectangular || circular).to_attributes
    end

    # The columns `buildVolume: null` clears
    def self.cleared_attributes
      { bed_shape: nil, build_volume_x: nil, build_volume_y: nil, build_volume_z: nil, build_diameter: nil }
    end
  end
end
