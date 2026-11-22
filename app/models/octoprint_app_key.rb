# typed: strict
# frozen_string_literal: true

# Faraday comes with the octoprint and prusalink gems, which load it only when they first make a client
require 'faraday'

# OctoPrint's Application Keys plugin, called by the server so that the API key never reaches the browser. The base
# of its two calls:
#
#   url = OctoprintAppKey.url(IPAddr.new('192.168.1.57'))   # => "http://192.168.1.57/"
#   request = OctoprintAppKey::Request.create!(url:)        # POST /plugin/appkeys/request
#   request.app_token, request.auth_dialog_url
#   poll = OctoprintAppKey::Poll.create!(url:, app_token:)  # GET /plugin/appkeys/request/<app_token>
#   poll.decision, poll.api_key                             # :waiting, :approved (with the key) or :denied
#
# Not to be confused with Printer::AppKeyRequest, Tentacles' own record of a request while it waits (in Redis).
#
# The octoprint gem needs an API key for every call, so this is plain Faraday. `save!` raises
# Printer::Backend::Unreachable when OctoPrint can't be reached and Printer::Backend::Error for any other unexpected
# answer, with messages that can be shown as they are (they never contain the app token or the key). `save` puts
# those messages in `errors[:base]` instead.
class OctoprintAppKey < ApplicationModel
  APP_NAME = 'Tentacles'
  # Seconds: OctoPrint drops a request that isn't polled for 5 seconds
  TIMEOUT = 3

  # The URL of the OctoPrint server
  attribute :url, :string

  validates :url, presence: true

  rescue_into_errors Printer::Backend::Error

  # "http://192.168.1.57/" for 192.168.1.57, "http://[fd00::57]/" for fd00::57. Built from a parsed IP address
  # only: never from text a client sent.
  sig { params(ip: IPAddr).returns(String) }
  def self.url(ip)
    "http://#{ip.ipv6? ? "[#{ip}]" : ip}/"
  end

  private

  sig { params(block: T.proc.params(http: Faraday::Connection).returns(Faraday::Response)).returns(Faraday::Response) }
  def http(&block)
    connection = Faraday.new(url:, headers: { 'Content-Type' => 'application/json' },
                             request: { open_timeout: TIMEOUT, timeout: TIMEOUT })
    block.call(connection)
  rescue Faraday::Error, URI::InvalidURIError
    raise Printer::Backend::Unreachable, "Could not reach OctoPrint at #{url}"
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
    raise Printer::Backend::Error, "#{url} does not answer like OctoPrint"
  end
end
