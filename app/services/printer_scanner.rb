# frozen_string_literal: true

class PrinterScanner
  # rubocop:disable Layout/LineLength
  IP_REGEX = /((?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/
  # rubocop:enable Layout/LineLength

  def call
    all_network_ips.select { |ip| octoprint?(ip) }
  end

  private

  def all_network_ips
    return [] unless local_ip

    network_scan = `nmap -sP #{local_ip}/24`
    network_scan.split("\n").map { |line| IP_REGEX.match(line) }.compact.map { |line| line[1] }
  end

  def octoprint?(ip)
    uri = URI("http://#{ip}/api/currentuser")
    begin
      res = Net::HTTP.get_response(uri)
      res.is_a?(Net::HTTPSuccess) && JSON.parse(res.body)['groups'] == ['guests']
    rescue StandardError
      false
    end
  end

  def local_ip
    Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
  end
end
