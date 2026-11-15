# frozen_string_literal: true

module Types
  class TemperatureUnit < Base::Enum
    description 'The unit of a temperature'

    value 'CELSIUS', 'Degrees Celsius (what OctoPrint reports)', value: ::TemperatureUnit::Celsius
    value 'FAHRENHEIT', 'Degrees Fahrenheit', value: ::TemperatureUnit::Fahrenheit
    value 'KELVIN', 'Kelvin', value: ::TemperatureUnit::Kelvin
  end
end
