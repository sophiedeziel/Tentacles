# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # The Add to Queue form: saves a ::PrintQueue::Addition
    class AddToQueue < Base::Mutation
      description 'Adds a file to the global queue, at the bottom or at the top. Refused when printerIds names a ' \
                  'printer that can never print it (see printerFits), e.g. "Mini Delta can\'t print it: Bed too ' \
                  'small: ...".'

      argument :file_id, ID, required: true
      argument :copies, Integer, required: false, default_value: 1, replace_null_with_default: true,
                                 description: 'How many copies, from 1 (default: 1)'
      argument :material, String, required: false,
                                  description: 'The material asked for, one of filamentMaterials. Null for the one ' \
                                               'its G-code says.'
      argument :colour, String, required: false, description: 'The colour asked for. Null for any colour.'
      argument :same_printer, Boolean, required: false, default_value: false, replace_null_with_default: true,
                                       description: 'Every copy on the same printer: the printer of the first copy ' \
                                                    '(default: false)'
      argument :printer_ids, [ID], required: false,
                                   description: 'Only on these printers. Null for every printer that can print it, ' \
                                                'printers added later included.'
      argument :position, Types::MovePrintJobTo, required: false, default_value: 'bottom',
                                                 replace_null_with_default: true,
                                                 description: 'BOTTOM (End of Queue, the default) or TOP (Next Up: ' \
                                                              'ahead of everything waiting)'
      argument :held, Boolean, required: false, default_value: false, replace_null_with_default: true,
                               description: 'Held: it keeps its place, but no copy starts until it is released'

      field :success, Boolean, null: false, description: 'Whether it was added'
      field :errors, [Types::UserError], null: false, description: 'Why it was refused, empty when it was added'
      field :print_job, Types::PrintJob, null: true, description: 'The print job added, null when refused'

      #: (file_id: String, ?printer_ids: Array[String]?, **untyped) -> Hash[Symbol, untyped]
      def resolve(file_id:, printer_ids: nil, **)
        item = ::Library::Item.find_by(id: file_id)
        return failure([Types::UserError.base('File not found')]) if item.nil?

        addition = ::PrintQueue::Addition.new(item:, all_capable: printer_ids.nil?, printer_ids: printer_ids || [],
                                              **)
        return { success: true, errors: [], print_job: addition.job } if addition.save

        failure(Types::UserError.from(addition.errors))
      end

      private

      #: (Array[Hash[Symbol, String?]] errors) -> Hash[Symbol, untyped]
      def failure(errors) = { success: false, errors:, print_job: nil }
    end
  end
end
