# frozen_string_literal: true

module Mutations
  class StartNextPrint < Mutations::BaseMutation
    description 'Mutation to start the next print in the queue for a printer'

    argument :printer_id, ID, required: true

    field :success, Boolean, null: false

    def resolve(printer_id:)
      printer = ::Printer.find(printer_id.to_i)

      printer.start_print
      { success: true }
    rescue StandardError
      { success: false }
    end
  end
end
