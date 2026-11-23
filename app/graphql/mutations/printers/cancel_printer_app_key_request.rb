# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # OctoPrint is not told: its own request expires
    class CancelPrinterAppKeyRequest < Base::Mutation
      description 'Stops waiting for an OctoPrint app key request. Pushes CANCELLED on printerAppKeyChanged.'

      argument :id, ID, required: true, description: 'The id returned by requestPrinterAppKey'

      field :request, Types::AppKeyRequest, null: true, description: 'The CANCELLED request, null when it was ' \
                                                                     'already over or expired'
      field :errors, [String], null: false, description: 'Why it was not cancelled, empty when it was'

      #: (id: String) -> Hash[Symbol, untyped]
      def resolve(id:)
        request = ::Printer::AppKeyRequest.take(id)
        return { request: nil, errors: ['This request is already over'] } if request.nil?

        request.push('cancelled')
        { request: request.payload('cancelled'), errors: [] }
      end
    end
  end
end
