# typed: strict
# frozen_string_literal: true

# Faraday comes with the octoprint and prusalink gems, which load it only when they first make a client
require 'faraday'

# OctoPrint's Application Keys plugin, called by the server so that the API key never reaches the browser:
#
#   app_keys = OctoprintAppKeys.new('http://192.168.1.57/')
#   app_token, auth_dialog = app_keys.request # POST /plugin/appkeys/request
#   app_keys.poll(app_token)                  # GET /plugin/appkeys/request/<app_token>: [:approved, api_key], ...
#
# The octoprint gem needs an API key for every call, so this is plain Faraday. Raises PrinterBackends::Unreachable
# when OctoPrint can't be reached and PrinterBackends::Error for any other unexpected answer, with messages that can
# be shown as they are (they never contain the app token or the key).
class OctoprintAppKeys
  extend T::Sig

  APP_NAME = 'Tentacles'
  # Seconds: OctoPrint drops a request that isn't polled for 5 seconds
  TIMEOUT = 3

  # "http://192.168.1.57/" for "192.168.1.57"; a URL is kept as it is
  sig { params(address: String).returns(String) }
  def self.url(address)
    address.match?(%r{\Ahttps?://}i) ? address : "http://#{address}/"
  end

  sig { params(url: String).void }
  def initialize(url)
    @url = url
  end

  # Asks OctoPrint for a key for Tentacles. Returns the request's app token, and the URL of the dialog where the user
  # approves it (OctoPrint 1.8+; nil before).
  sig { returns([String, T.nilable(String)]) }
  def request
    response = call { |http| http.post('plugin/appkeys/request', { app: APP_NAME }.to_json) }
    case response.status
    when 201 then nil
    # OctoPrint takes 3 requests a minute at most
    when 429 then raise PrinterBackends::Error, "OctoPrint at #{@url} got too many requests. Try again in a minute."
    else
      raise PrinterBackends::Error, "OctoPrint at #{@url} refused the request (HTTP #{response.status}). Is its " \
                                    'Application Keys plugin enabled?'
    end

    body = parse(response)
    [string(body, 'app_token'), body['auth_dialog'].presence]
  end

  # [:waiting, nil] until the user decides, [:approved, api_key], or [:denied, nil] (denied, or expired)
  sig { params(app_token: String).returns([Symbol, T.nilable(String)]) }
  def poll(app_token)
    response = call { |http| http.get("plugin/appkeys/request/#{app_token}") }
    case response.status
    when 202 then [:waiting, nil]
    when 404 then [:denied, nil]
    when 200 then [:approved, string(parse(response), 'api_key')]
    else raise PrinterBackends::Error, "OctoPrint at #{@url} answered HTTP #{response.status}"
    end
  end

  private

  sig { params(block: T.proc.params(http: Faraday::Connection).returns(Faraday::Response)).returns(Faraday::Response) }
  def call(&block)
    http = Faraday.new(url: @url, headers: { 'Content-Type' => 'application/json' },
                       request: { open_timeout: TIMEOUT, timeout: TIMEOUT })
    block.call(http)
  rescue Faraday::Error, URI::InvalidURIError
    raise PrinterBackends::Unreachable, "Could not reach OctoPrint at #{@url}"
  end

  sig { params(response: Faraday::Response).returns(T::Hash[String, T.untyped]) }
  def parse(response)
    body = JSON.parse(response.body.to_s)
    body.is_a?(Hash) ? body : not_octoprint
  rescue JSON::ParserError
    not_octoprint
  end

  sig { params(body: T::Hash[String, T.untyped], key: String).returns(String) }
  def string(body, key)
    value = body[key]
    value.is_a?(String) ? value : not_octoprint
  end

  sig { returns(T.noreturn) }
  def not_octoprint
    raise PrinterBackends::Error, "#{@url} does not answer like OctoPrint"
  end
end
