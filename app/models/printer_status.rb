# typed: strict
# frozen_string_literal: true

# Snapshot of a printer's live state, built by the printer monitor and stored in Redis (see PrinterStatusStore).
#
# GraphQL resolvers read these snapshots instead of calling OctoPrint.
class PrinterStatus < T::Struct
  extend T::Sig

  # Value equality for the snapshot structs (T::Struct compares by identity)
  module Equality
    extend T::Sig

    sig { params(other: T.untyped).returns(T::Boolean) }
    def ==(other)
      T.bind(self, T::Struct)
      other.instance_of?(self.class) && other.serialize == serialize
    end
    alias eql? ==

    sig { returns(Integer) }
    def hash
      T.bind(self, T::Struct)
      [self.class, serialize].hash
    end
  end

  include Equality

  class Temperature < T::Struct
    include Equality
    extend T::Sig

    const :actual, T.nilable(Float)
    const :target, T.nilable(Float)

    # Rounded to 1°, for change detection
    sig { returns([T.nilable(Integer), T.nilable(Integer)]) }
    def rounded
      [actual&.round, target&.round]
    end
  end

  class Camera < T::Struct
    include Equality

    const :enabled, T::Boolean, default: false
    # Absolute URL of the webcam stream
    const :stream_url, T.nilable(String)
  end

  # Times from ActiveRecord and Time.current are TimeWithZone
  TimeLike = T.type_alias { T.any(Time, ActiveSupport::TimeWithZone) }

  UNKNOWN_STATE_TEXT = 'Unknown'
  TIME_PROPS = T.let(%w[last_seen_at updated_at].freeze, T::Array[String])

  const :printer_id, Integer
  const :state_family, PrinterStateFamily
  const :state_text, String
  const :error_text, T.nilable(String)
  const :file_name, T.nilable(String)
  # Completion of the current job, in percent (0 to 100)
  const :progress, T.nilable(Float)
  # Estimated time left for the current job, in seconds
  const :print_time_left, T.nilable(Integer)
  const :hotend, T.nilable(Temperature)
  const :bed, T.nilable(Temperature)
  const :camera, Camera, factory: -> { Camera.new }
  # Last time the monitor reached OctoPrint
  const :last_seen_at, T.nilable(TimeLike)
  # When the snapshot was built
  const :updated_at, T.nilable(TimeLike)

  # Placeholder for printers the monitor hasn't reported on yet
  sig { params(printer_id: Integer, last_seen_at: T.nilable(TimeLike)).returns(PrinterStatus) }
  def self.unknown(printer_id:, last_seen_at: nil)
    new(printer_id:, state_family: PrinterStateFamily::Offline, state_text: UNKNOWN_STATE_TEXT, last_seen_at:)
  end

  sig { params(json: String).returns(PrinterStatus) }
  def self.from_json(json)
    hash = JSON.parse(json)
    TIME_PROPS.each { |prop| hash[prop] = Time.iso8601(hash[prop]) if hash[prop] }
    from_hash(hash)
  end

  sig { params(_args: T.untyped).returns(String) }
  def to_json(*_args)
    hash = serialize
    TIME_PROPS.each { |prop| hash[prop] = hash[prop]&.utc&.iso8601(3) }
    hash.to_json
  end

  # The values that matter for change detection: temperatures rounded to 1°, progress to 1 % and time left to
  # 1 minute. Timestamps are left out, so a snapshot only counts as changed when the printer's state did.
  sig { returns(T::Hash[Symbol, T.untyped]) }
  def comparable_attributes
    {
      state_family:, state_text:, error_text:, file_name:,
      progress: progress&.round,
      print_time_left: print_time_left&.then { |seconds| (seconds / 60.0).round },
      hotend: hotend&.rounded,
      bed: bed&.rounded,
      camera: camera.serialize
    }
  end

  sig { params(other: T.nilable(PrinterStatus)).returns(T::Boolean) }
  def same_as?(other)
    !other.nil? && comparable_attributes == other.comparable_attributes
  end
end
