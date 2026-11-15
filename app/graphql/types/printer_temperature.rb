# frozen_string_literal: true

module Types
  # A ::PrinterStatus::Temperature (named PrinterTemperature: Temperature is taken by Types::GcodeAnalysis::Temperature)
  class PrinterTemperature < Base::Object
    description 'A heater temperature, in °C'
    default_broadcastable true

    field :actual, Float, null: true, description: 'Current temperature'
    field :target, Float, null: true, description: 'Target temperature (0 when the heater is off)'
  end
end
