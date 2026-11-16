# frozen_string_literal: true

module Types
  class BuildVolume < Base::Union
    description "A printer's build volume, by bed shape"

    possible_types Types::RectangularBuildVolume, Types::CircularBuildVolume

    # `object` is the Hash built by PrinterSpecs#build_volume
    def self.resolve_type(object, _context)
      object.key?(:diameter) ? Types::CircularBuildVolume : Types::RectangularBuildVolume
    end
  end
end
