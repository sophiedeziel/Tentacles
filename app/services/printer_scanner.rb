# frozen_string_literal: true

class PrinterScanner
  # rubocop:disable-next Layout/LineLength
  IP_REGEX = /((?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/

  # The IP address of every OctoPrint server on the local /24 network (they answer the appkeys probe), the saved
  # printers' included. The scan is cached 15 minutes in Redis; `refresh: true` scans again.
  def call(refresh: false)
    use_cache(refresh:) do
      all_network_ips.select { |ip| octoprint?(ip) }
    end
  end

  private

  def use_cache(refresh:)
    unless refresh
      cached_ips = REDIS_POOL.with { |conn| conn.get(:printers_ips) }
      return JSON.parse(cached_ips) if cached_ips && last_printer_scan > 15.minutes.ago.to_i
    end

    yield.tap { |ips| store_printers_ips(ips) }
  end

  def last_printer_scan
    REDIS_POOL.with do |conn|
      conn.get(:last_printer_scan).to_i
    end
  end

  def store_printers_ips(ips)
    REDIS_POOL.with do |conn|
      conn.set(:printers_ips, ips.to_json)
      conn.set(:last_printer_scan, Time.now.to_i)
    end
  end

  def all_network_ips
    return [] unless local_ip

    network_scan.split("\n").map { |line| IP_REGEX.match(line) }.compact.pluck(1)
  end

  def octoprint?(ip)
    uri = URI("http://#{ip}/plugin/appkeys/probe")
    begin
      res = Net::HTTP.get_response(uri)
      res.is_a?(Net::HTTPSuccess) && res.code == '204'
    rescue StandardError
      false
    end
  end

  def local_ip
    Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
  end

  def network_scan
    @network_scan ||= `nmap -sP #{local_ip}/24`
  end
end
