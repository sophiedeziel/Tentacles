# frozen_string_literal: true

module Mutations
  module Printers
    class AddPrinter < Base::Mutation
      description 'Mutation to add a printer configuration'

      argument :octoprint_uri, String, required: true
      argument :octoprint_key, String, required: true
      argument :name, String, required: true

      field :printer, Types::Printer, null: true

      def resolve(name:, octoprint_uri:, octoprint_key:)
        printer = ::Printer.new(name:, backend: 'octoprint', uri: octoprint_uri, secret: octoprint_key)
        if printer.save
          { printer: }
        else
          { printer: nil }
        end
      end
    end
  end
end
