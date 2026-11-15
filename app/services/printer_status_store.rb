# typed: strict
# frozen_string_literal: true

# Reads and writes PrinterStatus snapshots and the printer monitor's heartbeat in Redis.
module PrinterStatusStore
  extend T::Sig

  KEY_PREFIX = 'printer_status:'
  HEARTBEAT_KEY = 'printer_monitor:heartbeat'
  # The monitor counts as healthy when its last heartbeat is more recent than this
  HEALTHY_WITHIN = T.let(15.seconds, ActiveSupport::Duration)

  class << self
    extend T::Sig

    sig { params(printer_id: Integer).returns(String) }
    def key(printer_id)
      "#{KEY_PREFIX}#{printer_id}"
    end

    sig { params(status: PrinterStatus).void }
    def write(status)
      REDIS_POOL.with { |conn| conn.set(key(status.printer_id), status.to_json) }
    end

    # Reads the snapshots of many printers with a single MGET. Printers without a snapshot are left out.
    sig { params(printer_ids: T::Array[Integer]).returns(T::Hash[Integer, PrinterStatus]) }
    def read_many(printer_ids)
      return {} if printer_ids.empty?

      values = REDIS_POOL.with { |conn| conn.mget(*printer_ids.map { |id| key(id) }) }
      printer_ids.zip(values).each_with_object({}) do |(printer_id, json), statuses|
        status = parse(printer_id, json)
        statuses[printer_id] = status if status
      end
    end

    sig { params(printer_id: Integer).returns(T.nilable(PrinterStatus)) }
    def read(printer_id)
      read_many([printer_id])[printer_id]
    end

    sig { params(printer_ids: T::Array[Integer]).void }
    def delete(printer_ids)
      return if printer_ids.empty?

      REDIS_POOL.with { |conn| conn.del(*printer_ids.map { |id| key(id) }) }
    end

    sig { params(at: PrinterStatus::TimeLike).void }
    def beat!(at: Time.current)
      REDIS_POOL.with { |conn| conn.set(HEARTBEAT_KEY, at.to_f.to_s) }
    end

    sig { returns(T.nilable(PrinterStatus::TimeLike)) }
    def last_heartbeat
      value = REDIS_POOL.with { |conn| conn.get(HEARTBEAT_KEY) }
      value.present? ? Time.zone.at(Float(value)) : nil
    rescue ArgumentError, TypeError
      nil
    end

    # False when Redis can't be reached either
    sig { params(now: PrinterStatus::TimeLike).returns(T::Boolean) }
    def monitor_healthy?(now: Time.current)
      heartbeat = last_heartbeat
      !heartbeat.nil? && now - heartbeat < HEALTHY_WITHIN
    rescue Redis::BaseError => e
      Rails.logger.warn("[PrinterStatusStore] Could not read the monitor heartbeat: #{e.message}")
      false
    end

    private

    sig { params(printer_id: Integer, json: T.nilable(String)).returns(T.nilable(PrinterStatus)) }
    def parse(printer_id, json)
      return nil if json.blank?

      PrinterStatus.from_json(json)
    rescue StandardError => e # Malformed JSON, or a snapshot written before a prop was added
      Rails.logger.warn("[PrinterStatusStore] Ignoring unreadable snapshot for printer #{printer_id}: #{e.message}")
      nil
    end
  end
end
