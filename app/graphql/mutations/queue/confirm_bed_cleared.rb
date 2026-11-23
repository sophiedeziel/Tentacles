# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # Bed Cleared: saves a ::PrintQueue::BedClearance
    class ConfirmBedCleared < Base::Mutation
      description "Bed Cleared: a person confirms the print they saw on the printer's bed was taken off it, so the " \
                  'printer can take its next print. Refused when there is nothing to clear, or when the bed now ' \
                  'holds another print than expectedPrintId.'

      argument :printer_id, ID, required: true
      argument :expected_print_id, ID, required: true,
                                       description: 'The print the person was shown on the bed (Printer.printOnBed): ' \
                                                    'a modal left open never clears a newer one'

      field :success, Boolean, null: false, description: 'Whether it was saved'
      field :errors, [Types::UserError], null: false, description: 'Why it was refused, empty when it was saved'
      field :printer, Types::Printer, null: true, description: 'The printer, null when it was not found'
      field :print, Types::Print, null: true, description: 'The print whose bed was cleared, null when refused'

      #: (printer_id: String, expected_print_id: String) -> Hash[Symbol, untyped]
      def resolve(printer_id:, expected_print_id:)
        printer = ::Printer.find_by(id: printer_id)
        if printer.nil?
          return { success: false, errors: [Types::UserError.base('Printer not found')], printer: nil, print: nil }
        end

        clearance = ::PrintQueue::BedClearance.new(printer:, expected_print_id:)
        return { success: true, errors: [], printer:, print: clearance.printer_job } if clearance.save

        { success: false, errors: Types::UserError.from(clearance.errors), printer:, print: nil }
      end
    end
  end
end
