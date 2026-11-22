# typed: true
# frozen_string_literal: true

class Printer
  # Remembers that a printer couldn't be reached, so that its API isn't called again for 10 minutes (see
  # Printer#using_api). Kept in Redis as JSON under `printer_<printer id>_disconnected`.
  #
  #   Printer::Disconnection.create!(printer_id: 1)    # for 10 minutes
  #   Printer::Disconnection.exists?(printer_id: 1)    # => true until then
  #   Printer::Disconnection.delete_by(printer_id: 1) # e.g. once its address changed
  class Disconnection < ApplicationModel
    DEFAULT_DURATION = T.let(10.minutes, ActiveSupport::Duration)

    attribute :printer_id, :integer
    # How long the printer counts as disconnected, from the save
    attribute :expires_in, default: -> { DEFAULT_DURATION }
    attribute :expires_at, TimeType.new

    validates :printer_id, :expires_in, presence: true

    class << self
      extend T::Sig

      sig { params(printer_id: Integer).returns(String) }
      def key(printer_id)
        "printer_#{printer_id}_disconnected"
      end

      # Whether the printer was found disconnected less than 10 minutes ago
      sig { params(printer_id: Integer).returns(T::Boolean) }
      def exists?(printer_id:)
        json = REDIS_POOL.with { |conn| conn.get(key(printer_id)) }
        return false if json.nil?

        JSON.parse(json, symbolize_names: true)[:expiration] > Time.current.to_i
      end

      # Deletes the flag without reading it (like ActiveRecord's delete_by)
      sig { params(printer_id: Integer).void }
      def delete_by(printer_id:)
        REDIS_POOL.with { |conn| conn.del(key(printer_id)) }
      end
    end

    private

    sig { void }
    def persist
      Rails.logger.info("Setting #{printer_id} to disconnected")
      self.expires_at = Time.current + expires_in
      REDIS_POOL.with { |conn| conn.set(self.class.key(T.must(printer_id)), { expiration: expires_at.to_i }.to_json) }
    end
  end
end
