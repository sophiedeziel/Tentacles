# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # The Edit page of a waiting print job: saves a ::PrintQueue::JobUpdate
    class UpdatePrintJob < PrintJobMutation
      description "Changes a print job's options, as addToQueue takes them but the file: every option is set, an " \
                  'omitted one takes its default. They apply to the copies still waiting. Its place and its hold ' \
                  'keep movePrintJob and holdPrintJob. Refused below the copies done and printing, and when ' \
                  'printerIds names a printer that can never print it.'

      argument :copies, Integer, required: true, description: 'From 1, and not below the copies done and printing'
      argument :material, String, required: false,
                                  description: 'The material asked for, one of filamentMaterials. Null for the one ' \
                                               'its G-code says.'
      argument :colour, String, required: false, description: 'The colour asked for. Null for any colour.'
      argument :same_printer, Boolean, required: false, default_value: false, replace_null_with_default: true,
                                       description: 'Every copy on the same printer (default: false). Off, or a ' \
                                                    'printer list without its printer, lets a bound batch go.'
      argument :printer_ids, [ID], required: false,
                                   description: 'Only on these printers. Null for every printer that can print it, ' \
                                                'printers added later included.'

      private

      def operation_for(job, printer_ids: nil, **)
        ::PrintQueue::JobUpdate.new(job:, all_capable: printer_ids.nil?, printer_ids: printer_ids || [], **)
      end
    end
  end
end
