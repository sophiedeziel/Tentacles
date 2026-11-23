# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # The Takes Jobs switch of the printer's page: saves a ::Printer::TakesJobsChange
    class SetPrinterTakesJobs < Base::Mutation
      description 'Whether a printer takes jobs from the global queue. A printer that does not is skipped by the ' \
                  'dispatcher; the print under way goes on. Refused while the global queue is off.'

      argument :printer_id, ID, required: true
      argument :takes_jobs, Boolean, required: true

      field :success, Boolean, null: false, description: 'Whether it was saved'
      field :errors, [Types::UserError], null: false, description: 'Why it was refused, empty when it was saved'
      field :printer, Types::Printer, null: true, description: 'The printer as saved, null when it was not found'

      #: (printer_id: String, takes_jobs: bool) -> Hash[Symbol, untyped]
      def resolve(printer_id:, takes_jobs:)
        printer = ::Printer.find_by(id: printer_id)
        return { success: false, errors: [Types::UserError.base('Printer not found')], printer: nil } if printer.nil?

        change = ::Printer::TakesJobsChange.new(printer:, takes_jobs:)
        return { success: true, errors: [], printer: } if change.save

        { success: false, errors: Types::UserError.from(change.errors), printer: printer.reload }
      end
    end
  end
end
