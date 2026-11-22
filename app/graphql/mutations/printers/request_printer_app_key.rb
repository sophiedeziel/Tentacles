# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # The OctoPrint approval, server side: the browser never calls OctoPrint and never sees the key. Only the
    # addresses the network scan found are called: the server never calls an address a client made up.
    class RequestPrinterAppKey < Base::Mutation
      extend T::Sig

      description 'Asks an OctoPrint server found by the network scan for an API key for Tentacles. The user ' \
                  'approves it in OctoPrint, at `approvalUrl`; the server then adds the printer with the key. ' \
                  'Follow the request with printerAppKeyChanged.'

      NOT_AN_IP = 'Enter the IP address of an OctoPrint server found by the network scan, e.g. 192.168.1.57'

      argument :address, String, required: true,
                                 description: 'The IP address of a NetworkPrinter (from the last networkPrinters ' \
                                              'scan), e.g. "192.168.1.57"'

      field :request, Types::AppKeyRequest, null: true, description: 'The WAITING request, null when OctoPrint ' \
                                                                     'could not be asked'
      field :errors, [String], null: false, description: 'Why OctoPrint could not be asked, empty when it was'

      sig { params(address: String).returns(T::Hash[Symbol, T.untyped]) }
      def resolve(address:)
        address = address.strip
        scanned = scanned_ip(address)
        return { request: nil, errors: [refusal(address)] } unless scanned

        { request: request_key(scanned).payload('waiting'), errors: [] }
      rescue Printer::Backend::Error => e
        { request: nil, errors: [e.message] }
      end

      # An IPv4 or IPv6 address; nil for anything else (a host name, a URL, a range like 192.168.1.0/24, a zone)
      sig { params(text: String).returns(T.nilable(IPAddr)) }
      def self.parse_ip(text)
        return if text.match?(%r{[/%]})

        IPAddr.new(text)
      rescue IPAddr::Error
        nil
      end

      private

      # The address of the last scan that is `address`, parsed from the scan's own text, not the client's
      sig { params(address: String).returns(T.nilable(IPAddr)) }
      def scanned_ip(address)
        ip = self.class.parse_ip(address)
        found = ip && ::NetworkScan.last&.ips&.find { |scanned| self.class.parse_ip(scanned.to_s) == ip }
        IPAddr.new(found) if found
      end

      # Asks OctoPrint at `ip` for a key, keeps the request and starts polling it
      sig { params(ip: IPAddr).returns(::Printer::AppKeyRequest) }
      def request_key(ip)
        url = OctoprintAppKey.url(ip)
        app_key = OctoprintAppKey::Request.create!(url:)
        request = ::Printer::AppKeyRequest.create!(address: ip.to_s, app_token: app_key.app_token,
                                                   approval_url: app_key.auth_dialog_url || url)
        OctoprintAppKeyPollJob.perform_later(T.must(request.id))
        request
      rescue Printer::Backend::Error => e
        Rails.logger.warn("[requestPrinterAppKey] Could not ask #{url.inspect} for an app key: #{e.class}")
        raise
      end

      # Why `address` is not called
      sig { params(address: String).returns(String) }
      def refusal(address)
        return 'Enter the address of the OctoPrint server' if address.empty?

        ip = self.class.parse_ip(address)
        ip ? "The network scan did not find OctoPrint at #{ip}. Scan the network again." : NOT_AN_IP
      end
    end
  end
end
