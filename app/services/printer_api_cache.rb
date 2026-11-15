# frozen_string_literal: true

# Caches printer API answers in Redis (see Printer#using_api), and remembers for 10 minutes that a printer couldn't
# be reached so that the API isn't called again in the meantime.
#
# Only JSON values are cached (strings, numbers, hashes, arrays, nil): they come back as they were stored, with
# symbolized hash keys.
module PrinterApiCache
  def self.use_cache(id:, method:, time:, &)
    return Rails.logger.info("Printer #{id} is disconnected, not calling API") && nil if disconnected?(id)

    key = "printer_api_#{id}_#{method}"
    return Rails.logger.info("Not using cache for #{key}") && yield if time.nil?

    cached = get_cache(key)
    return Rails.logger.info("Using cached value for #{key}") && cached if cached.present?

    yield.tap { |result| store_cache(key, result, time) }
  end

  def self.clear_cache(key)
    Rails.logger.info("Clearing cache for #{key}")
    REDIS_POOL.with do |conn|
      conn.del(key)
    end
  end

  def self.set_disconnected(id, time: 10.minutes)
    Rails.logger.info("Setting #{id} to disconnected")
    key = "printer_#{id}_disconnected"
    REDIS_POOL.with do |conn|
      conn.set(key, { expiration: (Time.zone.now + time).to_i }.to_json)
    end
  end

  def self.disconnected?(id)
    key = "printer_#{id}_disconnected"

    REDIS_POOL.with do |conn|
      result = conn.get(key)
      return false if result.nil?

      JSON.parse(result).deep_symbolize_keys[:expiration] > Time.now.to_i
    end
  end

  def self.serialize(value, time)
    { value:, expiration: (Time.zone.now + time).to_i }.to_json
  end

  def self.deserialize(json)
    result = JSON.parse(json).deep_symbolize_keys
    return nil unless result.present? && result[:expiration].to_i > Time.now.to_i

    result[:value]
  end

  def self.get_cache(key)
    REDIS_POOL.with do |conn|
      result = conn.get(key)
      deserialize(result) if result.present?
    end
  end

  def self.store_cache(key, value, time)
    return if time == false

    Rails.logger.info("Storing #{key} in cache")
    REDIS_POOL.with do |conn|
      conn.set(key, serialize(value, time))
    end
  end

  private_class_method :get_cache, :store_cache
end
