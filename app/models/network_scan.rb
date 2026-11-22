# typed: strict
# frozen_string_literal: true

# A scan of the local /24 network for OctoPrint servers (the addresses that answer the appkeys probe), the saved
# printers' included. Kept in Redis, and reused for 15 minutes:
#
#   scan = NetworkScan.create!                # reuses the last scan when it's under 15 minutes old
#   scan = NetworkScan.create!(refresh: true) # scans again
#   scan.ips                                  # => ["192.168.1.57"]
#   NetworkScan.last&.ips                     # the last scan, however old, without scanning: nil before the first
class NetworkScan < ApplicationModel
  # rubocop:disable-next Layout/LineLength
  IP_REGEX = /((?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/

  # How long a scan is reused when not refreshed
  REUSED_FOR = T.let(15.minutes, ActiveSupport::Duration)

  # Scan again instead of reusing a recent scan
  attribute :refresh, :boolean, default: false
  # The IP addresses found
  attribute :ips, default: -> { [] }
  attribute :scanned_at, :datetime

  class << self
    extend T::Sig

    # The last scan, however old; nil before the first one
    sig { returns(T.nilable(NetworkScan)) }
    def last
      ips, scanned_at = REDIS_POOL.with { |conn| conn.mget(:printers_ips, :last_printer_scan) }
      return if ips.nil?

      new(ips: JSON.parse(ips), scanned_at: scanned_at && Time.zone.at(scanned_at.to_i))
    end
  end

  private

  sig { void }
  def persist
    reused = reusable_scan
    reused ? assign_attributes(ips: reused.ips, scanned_at: reused.scanned_at) : scan
  end

  # The last scan when it's under REUSED_FOR old; never with `refresh`
  sig { returns(T.nilable(NetworkScan)) }
  def reusable_scan
    return if refresh

    last = self.class.last
    last if last && last.scanned_at.to_i > REUSED_FOR.ago.to_i
  end

  sig { void }
  def scan
    assign_attributes(ips: all_network_ips.select { |ip| octoprint?(ip) }, scanned_at: Time.current)
    REDIS_POOL.with do |conn|
      conn.set(:printers_ips, ips.to_json)
      conn.set(:last_printer_scan, scanned_at.to_i)
    end
  end

  sig { returns(T::Array[String]) }
  def all_network_ips
    return [] unless local_ip

    network_scan.split("\n").map { |line| IP_REGEX.match(line) }.compact.pluck(1)
  end

  sig { params(ip: String).returns(T::Boolean) }
  def octoprint?(ip)
    uri = URI("http://#{ip}/plugin/appkeys/probe")
    begin
      res = Net::HTTP.get_response(uri)
      res.is_a?(Net::HTTPSuccess) && res.code == '204'
    rescue StandardError
      false
    end
  end

  sig { returns(T.nilable(String)) }
  def local_ip
    Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
  end

  sig { returns(String) }
  def network_scan
    @network_scan ||= T.let(`nmap -sP #{local_ip}/24`, T.nilable(String))
  end
end
