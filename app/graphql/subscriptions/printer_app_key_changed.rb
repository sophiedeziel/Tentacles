# frozen_string_literal: true

module Subscriptions
  # Pushed on every change of an OctoPrint app key request (see Printer::AppKeyRequest#push):
  #
  #   TentaclesSchema.subscriptions.trigger(:printer_app_key_changed, { id: request.id }, request.payload('denied'))
  class PrinterAppKeyChanged < Subscriptions::BaseSubscription
    description 'An OctoPrint app key request whose state changed: ADDED, DENIED, FAILED or CANCELLED'
    type Types::AppKeyRequest, null: false

    argument :id, ID, required: true, description: 'The id returned by requestPrinterAppKey'

    # Nothing is sent on subscribe: requestPrinterAppKey returned the WAITING request
    def subscribe(id:) # rubocop:disable Lint/UnusedMethodArgument
      :no_response
    end

    # The payload passed to the trigger
    def update(id:) # rubocop:disable Lint/UnusedMethodArgument
      object
    end
  end
end
