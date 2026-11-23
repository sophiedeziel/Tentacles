# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # Adds a file to the global queue (no screen until phase 5: used to seed the queue). Saves a ::PrintQueue::Addition
    class AddToQueue < Base::Mutation
      description 'Adds a file to the global queue, at the bottom'

      argument :file_id, ID, required: true
      argument :copies, Integer, required: false, default_value: 1, replace_null_with_default: true,
                                 description: 'How many copies, from 1 (default: 1)'
      argument :colour, String, required: false, description: 'The colour asked for. Null for any colour.'
      argument :same_printer, Boolean, required: false, default_value: false, replace_null_with_default: true,
                                       description: 'Every copy on the same printer: the printer of the first copy ' \
                                                    '(default: false)'
      argument :printer_ids, [ID], required: false,
                                   description: 'Only on these printers. Null for every printer that can print it, ' \
                                                'printers added later included.'

      field :success, Boolean, null: false, description: 'Whether it was added'
      field :errors, [Types::UserError], null: false, description: 'Why it was refused, empty when it was added'
      field :print_job, Types::PrintJob, null: true, description: 'The print job added, null when refused'

      #: (
      #|   file_id: String,
      #|   ?copies: Integer,
      #|   ?colour: String?,
      #|   ?same_printer: bool,
      #|   ?printer_ids: Array[String]?
      #| ) -> Hash[Symbol, untyped]
      def resolve(file_id:, copies: 1, colour: nil, same_printer: false, printer_ids: nil)
        item = ::Library::Item.find_by(id: file_id)
        return failure([Types::UserError.base('File not found')]) if item.nil?

        addition = ::PrintQueue::Addition.new(item:, copies:, colour:, same_printer:, all_capable: printer_ids.nil?,
                                              printer_ids: printer_ids || [])
        return { success: true, errors: [], print_job: addition.job } if addition.save

        failure(Types::UserError.from(addition.errors))
      end

      private

      #: (Array[Hash[Symbol, String?]] errors) -> Hash[Symbol, untyped]
      def failure(errors) = { success: false, errors:, print_job: nil }
    end
  end
end
