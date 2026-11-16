# typed: true
# frozen_string_literal: true

module Resolvers
  # The scan of PrinterScanner, with the saved printer at each address: the one whose URL has that host (the first
  # added when several do)
  class NetworkPrinters < GraphQL::Schema::Resolver
    extend T::Sig

    argument_class Base::Argument

    description 'The OctoPrint servers on the local network, with the saved printer at each address. Scans the ' \
                'network (slow); the scan is cached 15 minutes.'

    type [Types::NetworkPrinter], null: false

    argument :refresh, Boolean, required: false, default_value: false, replace_null_with_default: true,
                                description: 'Scan again instead of reusing the last scan'

    sig { params(refresh: T::Boolean).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
    def resolve(refresh:)
      saved = ::Printer.order(:id).to_a.group_by { |printer| host_of(printer.uri) }
      ::PrinterScanner.new.call(refresh:).map do |address|
        { address:, url: "http://#{address}/", printer: saved[address]&.first }
      end
    end

    private

    # "192.168.1.57" for "http://192.168.1.57:80/", nil for a blank or invalid URL
    sig { params(uri: T.nilable(String)).returns(T.nilable(String)) }
    def host_of(uri)
      URI.parse(uri.to_s).host
    rescue URI::InvalidURIError
      nil
    end
  end
end
