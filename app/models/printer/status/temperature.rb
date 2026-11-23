# typed: true
# frozen_string_literal: true

class Printer
  class Status < ApplicationModel
    # A heater temperature of the snapshot (hotend, bed)
    #
    #   Printer::Status::Temperature.new(actual: 210.3, target: 210.0).rounded # => [210, 210]
    class Temperature < ApplicationModel
      include Equality
      include Serialization

      attribute :actual, :float
      attribute :target, :float
      # Snapshots written before the unit was stored are in °C, like everything OctoPrint reports
      attribute :unit, EnumType.new(TemperatureUnit), default: -> { TemperatureUnit::Celsius }

      # Types::TemperatureStatus#unit needs one. Reading it also raises KeyError for an unknown unit (see EnumType).
      validates :unit, presence: true

      # Rounded to 1°, for change detection
      #: -> [Integer?, Integer?]
      def rounded
        [actual&.round, target&.round]
      end
    end
  end
end
