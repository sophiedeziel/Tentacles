# frozen_string_literal: true

module Mutations
  class AddPrinter < Mutations::BaseMutation
    description 'Mutation to add a printer configuration'

    argument :octoprint_uri, String, required: true
    argument :octoprint_key, String, required: true
    argument :name, String, required: true

    field :printer, Types::PrinterType, null: true

    def resolve(**kargs)
      printer = Printer.new(kargs)
      if printer.save
        { printer: printer }
      else
        { printer: nil }
      end
    end
  end
end
