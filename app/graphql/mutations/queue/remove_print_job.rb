# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # Remove from Queue: saves a ::PrintQueue::WaitingCopiesRemoval
    class RemovePrintJob < PrintJobMutation
      description 'Remove from Queue: removes the copies of a print job that are still waiting. Copies printing go ' \
                  'on, and the print job leaves the queue once they end. A print job with no copy handed to a ' \
                  'printer is deleted.'

      field :deleted_print_job_id, ID, null: true,
                                       description: 'The id of the print job when it was deleted (none of its ' \
                                                    'copies had been handed to a printer): printJob is null then'

      #: (id: String) -> Hash[Symbol, untyped]
      def resolve(id:)
        payload = super
        return payload unless @removal&.job_deleted?

        payload.merge(print_job: nil, deleted_print_job_id: id)
      end

      private

      def operation_for(job)
        @removal = ::PrintQueue::WaitingCopiesRemoval.new(job:)
      end
    end
  end
end
