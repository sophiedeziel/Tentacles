# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # The queue page's Dispatch switch, off: saves a ::PrintQueue::DispatchPause
    class PauseDispatch < DispatchMutation
      description 'Pauses dispatch for the whole fleet: no copy starts until resumeDispatch. Copies already handed ' \
                  'to a printer go on. Pausing while paused changes nothing.'

      private

      def operation_class = ::PrintQueue::DispatchPause
    end
  end
end
