# typed: strict
# frozen_string_literal: true

# The unit of a temperature reading. OctoPrint reports °C.
class TemperatureUnit < T::Enum
  enums do
    Celsius = new('CELSIUS')
    Fahrenheit = new('FAHRENHEIT')
    Kelvin = new('KELVIN')
  end
end
