# typed: strict
# frozen_string_literal: true

# An OctoPrint app key request that is still waiting (see requestPrinterAppKey), kept in Redis while
# OctoprintAppKeyPollJob polls it. It holds OctoPrint's app token, never the API key. It's gone once it's over
# (approved, denied, failed or cancelled), and on its own after TTL when nobody follows it anymore.
class PrinterAppKeyRequest < T::Struct
  extend T::Sig

  # Longer than OctoPrint keeps a request waiting (10 minutes), so that the job always sees OctoPrint's answer
  TTL = T.let(15.minutes, ActiveSupport::Duration)

  # The values of Types::AppKeyRequestState
  STATES = T.let(%w[waiting added denied failed cancelled].freeze, T::Array[String])

  const :id, String
  const :address, String
  const :app_token, String
  const :approval_url, String

  class << self
    extend T::Sig

    sig { params(address: String, app_token: String, approval_url: String).returns(PrinterAppKeyRequest) }
    def create(address:, app_token:, approval_url:)
      request = new(id: SecureRandom.uuid, address:, app_token:, approval_url:)
      REDIS_POOL.with { |conn| conn.set(key(request.id), request.serialize.to_json, ex: TTL.to_i) }
      request
    end

    # nil once the request is over or expired
    sig { params(id: String).returns(T.nilable(PrinterAppKeyRequest)) }
    def find(id)
      from_json(REDIS_POOL.with { |conn| conn.get(key(id)) })
    end

    # Removes the request and returns it; nil when it was already gone. Only one caller gets it, so the job and
    # cancelPrinterAppKeyRequest can't both end the same request.
    sig { params(id: String).returns(T.nilable(PrinterAppKeyRequest)) }
    def take(id)
      from_json(REDIS_POOL.with { |conn| conn.getdel(key(id)) })
    end

    private

    sig { params(id: String).returns(String) }
    def key(id)
      "printer_app_key_request_#{id}"
    end

    sig { params(json: T.nilable(String)).returns(T.nilable(PrinterAppKeyRequest)) }
    def from_json(json)
      json && from_hash(JSON.parse(json))
    end
  end

  # The URL of the OctoPrint server, which the new printer gets
  sig { returns(String) }
  def url
    OctoprintAppKeys.url(address)
  end

  # What Types::AppKeyRequest reads: everything but the app token (which approval_url holds, though: see Types::AppKeyRequest)
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
end
