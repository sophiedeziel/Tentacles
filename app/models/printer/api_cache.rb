# typed: true
# frozen_string_literal: true

class Printer
  # A printer API answer cached in Redis (see Printer#using_api), as JSON under `printer_api_<printer id>_<method>`.
  #
  #   cache = Printer::ApiCache.find_or_create_by(printer_id: 1, api_method: 'version', expires_in: 2.hours) do
  #     printer.api.version # only called when there's no cached answer
  #   end
  #   cache.value                                                    # => "OctoPrint 1.11.2"
  #   Printer::ApiCache.find_by(printer_id: 1, api_method: 'version') # nil once expired
  #   Printer::ApiCache.delete_by(printer_id: 1)                     # every cached answer of the printer
  #
  # Only JSON values are cached (strings, numbers, hashes, arrays, nil): they come back as they were stored, with
  # symbolized hash keys. Blank values (nil, "", [], {}) are stored but never count as cached.
  class ApiCache < ApplicationModel
    attribute :printer_id, :integer
    # The Printer method whose answer it is (e.g. "version"). Not `method`, which would hide Object#method.
    attribute :api_method, :string
    attribute :value
    # How long the answer stays cached, from the save
    attribute :expires_in
    attribute :expires_at, TimeType.new

    validates :printer_id, :api_method, :expires_in, presence: true

    class << self
      #: (Integer printer_id, String api_method) -> String
      def key(printer_id, api_method)
        "printer_api_#{printer_id}_#{api_method}"
      end

      # nil when there's no cached answer: never stored, expired, or blank (see #blank?)
      #: (printer_id: Integer, api_method: String) -> Printer::ApiCache?
      def find_by(printer_id:, api_method:)
        json = REDIS_POOL.with { |conn| conn.get(key(printer_id, api_method)) }
        data = json.present? ? JSON.parse(json, symbolize_names: true) : nil
        new(printer_id:, api_method:, value: data[:value], expires_at: data[:expiration]).presence if data.is_a?(Hash)
      end

      # The cached answer, else the block's value, cached for `expires_in`. Like ActiveRecord's find_or_create_by,
      # but the block computes the value instead of receiving the new record. Redis errors are raised.
      #
      # `expires_in: false` reads the cache without storing the block's value: like ActiveRecord's, the method returns
      # the new entry unsaved when it's invalid (without expires_in).
      #: (
      #|   printer_id: Integer,
      #|   api_method: String,
      #|   expires_in: (ActiveSupport::Duration | FalseClass)
      #| ) { -> untyped } -> Printer::ApiCache
      def find_or_create_by(printer_id:, api_method:, expires_in:, &block)
        cached = find_by(printer_id:, api_method:)
        Rails.logger.info("Using cached value for #{key(printer_id, api_method)}") if cached
        cached || create(printer_id:, api_method:, expires_in:, value: block.call)
      end

      # Deletes the printer's cached answers without reading them (like ActiveRecord's delete_by), e.g. once it's
      # removed or its address changed
      #: (printer_id: Integer) -> void
      def delete_by(printer_id:)
        REDIS_POOL.with do |conn|
          keys = conn.scan_each(match: key(printer_id, '*')).to_a
          conn.del(*keys) if keys.any?
        end
      end
    end

    #: -> String
    def key
      self.class.key(T.must(printer_id), T.must(api_method))
    end

    # Expired, or without a value (nil, "", [], {}): it never counts as a cached answer (see .find_by)
    #: -> bool
    def blank?
      value.blank? || expires_at.to_i <= Time.current.to_i
    end

    private

    #: -> void
    def persist
      Rails.logger.info("Storing #{key} in cache")
      self.expires_at = Time.current + expires_in
      REDIS_POOL.with { |conn| conn.set(key, { value:, expiration: expires_at.to_i }.to_json) }
    end
  end
end
