# frozen_string_literal: true

module Subscriptions
  class PrinterSubscription < Subscriptions::BaseSubscription
    field :printer, Types::PrinterType, null: true
    argument :id, ID, required: true

    def subscribe(id:)
      # authorize, etc ...
      # Return the room in the initial response
      { printer: Printer.find(id) }
    end
  end
end
