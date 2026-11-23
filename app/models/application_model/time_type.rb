# typed: true
# frozen_string_literal: true

class ApplicationModel
  # The `:datetime` attribute type, but always in Time.zone (an ActiveSupport::TimeWithZone, like ActiveRecord's
  # times), and serialized (to JSON, by the type's #serialize) as ISO 8601 in UTC, to the millisecond:
  #
  #   attribute :updated_at, TimeType.new
  #
  #   status.updated_at = '2026-11-15T12:00:00.123Z' # => Sun, 15 Nov 2026 12:00:00.123 UTC +00:00 (TimeWithZone)
  #   status.updated_at = 1_794_744_000              # epoch seconds work too
  #   type.serialize(status.updated_at)              # => "2026-11-15T12:00:00.123Z"
  class TimeType < ActiveModel::Type::DateTime
    #: ((Time | ActiveSupport::TimeWithZone)? value) -> String?
    def serialize(value)
      value&.utc&.iso8601(3)
    end

    private

    #: (untyped value) -> ActiveSupport::TimeWithZone?
    def cast_value(value)
      value.is_a?(Numeric) ? Time.zone.at(value) : super&.in_time_zone
    end
  end
end
