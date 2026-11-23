# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # The copies field of the queue page: saves a ::PrintQueue::CopiesChange
    class SetPrintJobCopies < PrintJobMutation
      description 'Changes how many copies a print job asks for. Refused below the copies done and printing, e.g. ' \
                  '"Can\'t go below 3: 2 done and 1 printing". Raising the copies of a finished print job puts it ' \
                  'back in the queue, at the bottom (Requeue).'

      argument :copies, Integer, required: true, description: 'From 1, and not below the copies done and printing'

      private

      def operation_for(job, copies:) = ::PrintQueue::CopiesChange.new(job:, copies:)
    end
  end
end
