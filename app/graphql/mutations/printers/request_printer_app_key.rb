# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # The OctoPrint approval, server side: the browser never calls OctoPrint and never sees the key
    class RequestPrinterAppKey < Base::Mutation
      extend T::Sig

      description 'Asks an OctoPrint server for an API key for Tentacles. The user approves it in OctoPrint, at ' \
                  '`approvalUrl`; the server then adds the printer with the key. Follow the request with ' \
                  'printerAppKeyChanged.'

      argument :address, String, required: true,
                                 description: 'The OctoPrint server: a NetworkPrinter address, e.g. "192.168.1.57", ' \
                                              'or its URL'

      field :request, Types::AppKeyRequest, null: true, description: 'The WAITING request, null when OctoPrint ' \
                                                                     'could not be asked'
      field :errors, [String], null: false, description: 'Why OctoPrint could not be asked, empty when it was'

      sig { params(address: String).returns(T::Hash[Symbol, T.untyped]) }
      def resolve(address:)
        address = address.strip
        return { request: nil, errors: ['Enter the address of the OctoPrint server'] } if address.empty?

        url = OctoprintAppKeys.url(address)
        app_token, auth_dialog = OctoprintAppKeys.new(url).request
        request = PrinterAppKeyRequest.create(address:, app_token:, approval_url: auth_dialog || url)
        OctoprintAppKeyPollJob.perform_later(request.id)
        { request: request.payload('waiting'), errors: [] }
      rescue PrinterBackends::Error => e
        Rails.logger.warn("[requestPrinterAppKey] Could not ask #{url.inspect} for an app key: #{e.class}")
        { request: nil, errors: [e.message] }
      end
    end
  end
end
