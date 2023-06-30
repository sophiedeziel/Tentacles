# frozen_string_literal: true

module OctoprintCache
  def self.use_cache(id:, method:, time:, &)
    return Rails.logger.info("Printer #{id} is disconnected, not calling API") && nil if disconnected?(id)

    key = "printer_#{id}_#{method}"
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

  def self.serialize(object)
    { value: object, object_type: object.class }
  end

  def self.deserialize(json)
    result = JSON.parse(json).deep_symbolize_keys

    if result.present? && result[:expiration] > Time.now.to_i
      case result[:object_type]
      when 'NilClass'
        return result[:value]
      else
        return result[:object_type].constantize.new(**result[:value])
      end
    end

    nil
  end

  def self.get_cache(key)
    REDIS_POOL.with do |conn|
      result = conn.get(key)
      deserialize(result) if result.present?
    end
  end

  def self.store_cache(key, value, time)
    Rails.logger.info("Storing #{key} in cache")
    REDIS_POOL.with do |conn|
      conn.set(key, serialize(value).merge(expiration: (Time.zone.now + time).to_i).to_json)
    end
  end

  private_class_method :get_cache, :store_cache
end
