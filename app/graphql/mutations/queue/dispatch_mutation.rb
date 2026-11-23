# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # Base of pauseDispatch and resumeDispatch: saves a fleet-level queue operation
    # @abstract
    class DispatchMutation < Base::Mutation
      field :success, Boolean, null: false, description: 'Whether it was saved'
      field :errors, [Types::UserError], null: false, description: 'Why it was refused, empty when it was saved'
      field :global_queue, Types::GlobalQueue, null: true,
                                               description: 'The queue (dispatchPaused), null while it is off'

      #: -> Hash[Symbol, untyped]
      def resolve
        operation = operation_class.new
        saved = operation.save
        { success: saved, errors: saved ? [] : Types::UserError.from(operation.errors),
          global_queue: ({} if ::PrintQueue.enabled?) }
      end

      private

      # @abstract
      #: -> singleton(::PrintQueue::Operation)
      def operation_class = super
    end
  end
end
