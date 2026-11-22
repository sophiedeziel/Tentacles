# typed: true
# frozen_string_literal: true

class Printer
  # Snapshot of a printer's live state, built by the printer monitor and kept in Redis as JSON, under
  # `printer_status:<printer id>`. GraphQL resolvers read these snapshots instead of calling the printer.
  #
  #   status = Printer::Status.new(printer:, state_family: Printer::StateFamily::Operational, state_text: 'Operational')
  #   status.save!                                   # writes it and pushes printerStatusChanged
  #   Printer::Status.find_by(printer_id: printer.id) # => Printer::Status, nil without a (readable) snapshot
  #   Printer::Status.where(printer_id: [1, 2, 3])   # => [Printer::Status, ...] with a single MGET
  #   Printer::Status.delete_by(printer_id: [1, 2])  # once the printers are gone
  #
  # The live state is read from the printer's server with #reload, and saved only when it changed (the monitor's
  # tick, which Printer::Command also runs inline after a command):
  #
  #   status = Printer::Status.find_or_initialize_by(printer:).reload
  #   status.save! if status.changed?
  class Status < ApplicationModel
    include Equality
    include Serialization
    include ChangeTracking

    # Times from ActiveRecord and Time.current are TimeWithZone
    TimeLike = T.type_alias { T.any(Time, ActiveSupport::TimeWithZone) }

    KEY_PREFIX = 'printer_status:'
    UNKNOWN_STATE_TEXT = 'Unknown'
    # The state text of the snapshot the monitor writes when the printer's server doesn't answer
    UNREACHABLE_STATE_TEXT = 'Unreachable'

    attribute :printer_id, :integer
    attribute :state_family, EnumType.new(Printer::StateFamily)
    attribute :state_text, :string
    attribute :error_text, :string
    attribute :file_name, :string
    # Completion of the current job, in percent (0 to 100)
    attribute :progress, :float
    # Estimated time left for the current job, in seconds
    attribute :print_time_left, :integer
    attribute :hotend, ModelType.new(Temperature)
    attribute :bed, ModelType.new(Temperature)
    attribute :camera, ModelType.new(Camera), default: -> { Camera.new }
    # Last time the monitor reached the printer
    attribute :last_seen_at, TimeType.new
    # When the snapshot was built
    attribute :updated_at, TimeType.new

    # Snapshots missing one of these (e.g. written before it existed) are unreadable
    validates :printer_id, :state_family, :state_text, :camera, presence: true

    # The printerStatusChanged subscribers get the printer (see Subscriptions::PrinterStatusChanged). Once they did,
    # the state counts as saved (see #changed?): when pushing fails, the next tick saves it again.
    after_save :push_status_changed, :changes_applied

    class << self
      extend T::Sig

      sig { params(printer_id: Integer).returns(String) }
      def key(printer_id)
        "#{KEY_PREFIX}#{printer_id}"
      end

      # Placeholder for printers the monitor hasn't reported on yet
      sig { params(printer_id: Integer, last_seen_at: T.nilable(TimeLike)).returns(Printer::Status) }
      def unknown(printer_id:, last_seen_at: nil)
        new(printer_id:, state_family: Printer::StateFamily::Offline, state_text: UNKNOWN_STATE_TEXT, last_seen_at:)
      end

      # The snapshots of the printers, read with a single MGET, in the order of the ids. Printers without a snapshot,
      # or with an unreadable one, are left out.
      sig { params(printer_id: T.any(Integer, T::Array[Integer])).returns(T::Array[Printer::Status]) }
      def where(printer_id:)
        printer_ids = Array(printer_id)
        return [] if printer_ids.empty?

        values = REDIS_POOL.with { |conn| conn.mget(*printer_ids.map { |id| key(id) }) }
        printer_ids.zip(values).filter_map { |id, json| parse(id, json) }
      end

      sig { params(printer_id: Integer).returns(T.nilable(Printer::Status)) }
      def find_by(printer_id:)
        where(printer_id:).first
      end

      # The printer's snapshot, or a new one (not saved) when it has none or an unreadable one. Redis errors are raised.
      sig { params(printer: ::Printer).returns(Printer::Status) }
      def find_or_initialize_by(printer:)
        status = find_by(printer_id: printer.id) || new
        status.printer = printer
        status
      end

      # Deletes the snapshots without reading them (like ActiveRecord's delete_by), with a single DEL
      sig { params(printer_id: T.any(Integer, T::Array[Integer])).void }
      def delete_by(printer_id:)
        printer_ids = Array(printer_id)
        return if printer_ids.empty?

        REDIS_POOL.with { |conn| conn.del(*printer_ids.map { |id| key(id) }) }
      end

      private

      sig { params(printer_id: Integer, json: T.nilable(String)).returns(T.nilable(Printer::Status)) }
      def parse(printer_id, json)
        return nil if json.blank?

        status = new.from_json(json)
        return status.tap(&:changes_applied) if status.valid?

        Rails.logger.warn("[Printer::Status] Ignoring the incomplete snapshot of printer #{printer_id}: " \
                          "#{status.errors.full_messages.to_sentence}")
        nil
      rescue StandardError => e # Malformed JSON, or an unknown enum value
        Rails.logger.warn("[Printer::Status] Ignoring unreadable snapshot for printer #{printer_id}: #{e.message}")
        nil
      end
    end

    # The printer of the snapshot, loaded from printer_id unless it was given (`new(printer:, ...)`, which also sets
    # printer_id). Not an attribute: it's neither stored nor compared.
    sig { returns(::Printer) }
    def printer
      @printer ||= T.let(::Printer.find(T.must(printer_id)), T.nilable(::Printer))
    end

    sig { params(printer: ::Printer).void }
    def printer=(printer)
      @printer = printer
      self.printer_id = printer.id
    end

    # Whether the printer's server (OctoPrint, PrusaLink) answered the monitor, whatever the state of the printer
    # behind it. False when it couldn't be reached, and for the placeholder of a printer the monitor hasn't reported on
    # yet: the only snapshot without a time.
    sig { returns(T::Boolean) }
    def server_reachable?
      !updated_at.nil? && state_text != UNREACHABLE_STATE_TEXT
    end

    # Re-reads the printer's live state from its server (OctoPrint, PrusaLink), like ActiveRecord's #reload re-reads
    # the row: the state, job and temperatures are replaced, and the snapshot is stamped as seen and updated now.
    # Nothing is saved (see #save! and ChangeTracking#changed?).
    #
    # The camera is kept: its settings rarely change and are read separately (see Printer::Monitor::WebcamTracker).
    # Raises Printer::Backend::Error (e.g. Unreachable) when the server can't be read, leaving the snapshot as it was.
    # The reader defaults to a new one for the printer's backend; the monitor passes its own, which keeps state
    # between reloads (see Printer::Monitor::PrusalinkReader).
    #
    #   status.reload                        # => status
    #   status.reload(reader: worker_reader) # with the reader the monitor keeps
    sig { params(reader: Printer::Monitor::Reader).returns(T.self_type) }
    def reload(reader: Printer::Monitor::Reader.for(printer))
      attributes = reader.status_attributes
      now = Time.current
      assign_attributes(attributes.merge(last_seen_at: now, updated_at: now))
      self
    end

    private

    sig { void }
    def persist
      REDIS_POOL.with { |conn| conn.set(self.class.key(T.must(printer_id)), to_json) }
    end

    sig { void }
    def push_status_changed
      TentaclesSchema.subscriptions.trigger(:printer_status_changed, {}, printer)
    end
  end
end
