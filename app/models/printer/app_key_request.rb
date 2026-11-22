# typed: strict
# frozen_string_literal: true

class Printer
  # An OctoPrint app key request that is still waiting (see requestPrinterAppKey), kept in Redis while
  # OctoprintAppKeyPollJob polls it. It holds OctoPrint's app token, never the API key. It's gone once it's over
  # (approved, denied, failed or cancelled), and on its own after TTL when nobody follows it anymore.
  #
  #   request = Printer::AppKeyRequest.create!(address: '192.168.1.57', app_token:, approval_url:)
  #   Printer::AppKeyRequest.find(request.id) # nil once it's over or expired
  #   Printer::AppKeyRequest.take(request.id) # removes it, for one caller only
  #
  # The call that asks OctoPrint for the key is Printer::Backend::Octoprint::AppKey::Request.
  class AppKeyRequest < ApplicationModel
    # Longer than OctoPrint keeps a request waiting (10 minutes), so that the job always sees OctoPrint's answer
    TTL = T.let(15.minutes, ActiveSupport::Duration)

    # The values of Types::AppKeyRequestState
    STATES = T.let(%w[waiting added denied failed cancelled].freeze, T::Array[String])

    attribute :id, :string, default: -> { SecureRandom.uuid }
    attribute :address, :string
    attribute :app_token, :string
    attribute :approval_url, :string

    validates :id, :address, :app_token, :approval_url, presence: true

    class << self
      extend T::Sig

      # nil once the request is over or expired
      sig { params(id: String).returns(T.nilable(Printer::AppKeyRequest)) }
      def find(id)
        from_json(REDIS_POOL.with { |conn| conn.get(key(id)) })
      end

      # Removes the request and returns it; nil when it was already gone. Only one caller gets it, so the job and
      # cancelPrinterAppKeyRequest can't both end the same request.
      sig { params(id: String).returns(T.nilable(Printer::AppKeyRequest)) }
      def take(id)
        from_json(REDIS_POOL.with { |conn| conn.getdel(key(id)) })
      end

      sig { params(id: String).returns(String) }
      def key(id)
        "printer_app_key_request_#{id}"
      end

      private

      # The JSON of #persist (the attributes)
      sig { params(json: T.nilable(String)).returns(T.nilable(Printer::AppKeyRequest)) }
      def from_json(json)
        json && new(JSON.parse(json))
      end
    end

    # The URL of the OctoPrint server, which the new printer gets. `address` is an IP address the network scan found
    # (see requestPrinterAppKey).
    sig { returns(String) }
    def url
      Backend::Octoprint::AppKey.url(IPAddr.new(address))
    end

    # What Types::AppKeyRequest reads: everything but the app token (which approval_url holds, though: see
    # Types::AppKeyRequest)
    sig do
      params(state: String, printer: T.nilable(Printer), error: T.nilable(String)).returns(T::Hash[Symbol, T.untyped])
    end
    def payload(state, printer: nil, error: nil)
      raise ArgumentError, "Unknown state #{state.inspect}" unless STATES.include?(state)

      { id:, address:, approval_url:, state:, printer:, error: }
    end

    # Pushes printerAppKeyChanged to the subscribers of this request
    sig { params(state: String, printer: T.nilable(Printer), error: T.nilable(String)).void }
    def push(state, printer: nil, error: nil)
      TentaclesSchema.subscriptions.trigger(:printer_app_key_changed, { id: }, payload(state, printer:, error:))
    end

    private

    # Writes the attributes to Redis, expiring after TTL
    sig { void }
    def persist
      REDIS_POOL.with { |conn| conn.set(self.class.key(T.must(id)), attributes.to_json, ex: TTL.to_i) }
    end
  end
end
