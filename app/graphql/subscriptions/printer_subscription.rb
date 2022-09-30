# frozen_string_literal: true

module Subscriptions
  class PrinterSubscription < Subscriptions::BaseSubscription
    field :printer, Types::PrinterType, null: true
    argument :id, ID, required: true

    def subscribe(id:)
      # authorize, etc ...
      # Return the room in the initial response
      { printer: printer_scope.find(id) }
    end

    def update(id:)
      { printer: printer_scope.find(id) }
    end

    def printer_scope
      Printer.includes({ jobs: { executable: { file: :blob } } })
    end
  end
end
