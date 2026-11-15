# frozen_string_literal: true

module Types
  # A ::PrinterStatus::Temperature with a reading (see Types::PrinterStatus#temperature)
  class TemperatureStatus < Base::Object
    description 'A heater temperature'
    default_broadcastable true

    field :actual, Float, null: false, description: 'Current temperature, rounded to 1 degree'
    field :target, Float, null: false, description: 'Target temperature, rounded to 1 degree (0 when the heater is off)'
    field :unit, Types::TemperatureUnit, null: false

    def actual
      object.actual.round.to_f
    end

    def target
      (object.target || 0.0).round.to_f
    end
  end
end
