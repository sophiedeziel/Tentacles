# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # The queue page's drag to reorder (beforeId) and its Move to Top / Move to Bottom (to): saves a ::PrintQueue::Move
    class MovePrintJob < PrintJobMutation
      description 'Moves a print job to the top or the bottom of the queue (to), or right before another print job ' \
                  'still in the queue (beforeId): give one of them. The print jobs still in the queue are numbered ' \
                  '1..n in their new order.'

      argument :to, Types::MovePrintJobTo, required: false, description: 'Top or bottom. Null when beforeId is given.'
      argument :before_id, ID, required: false,
                               description: 'The print job it goes right before, e.g. the row it was dropped ' \
                                            'above. Null when `to` is given.'

      field :global_queue, Types::GlobalQueue, null: true,
                                               description: 'The queue, to read its new order (waiting). Null while ' \
                                                            'the global queue is off.'

      #: (id: String, ?to: String?, ?before_id: String?) -> Hash[Symbol, untyped]
      def resolve(id:, to: nil, before_id: nil)
        before = ::PrintQueue::Job.find_by(id: before_id) if before_id
        payload = if before_id && before.nil?
                    not_found('The print job to move it before was not found', field: 'beforeId')
                  else
                    super(id:, to:, before:)
                  end
        payload.merge(global_queue: ({} if ::PrintQueue.enabled?))
      end

      private

      def operation_for(job, to:, before:) = ::PrintQueue::Move.new(job:, to:, before:)
    end
  end
end
