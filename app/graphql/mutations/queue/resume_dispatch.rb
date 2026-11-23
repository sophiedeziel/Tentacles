# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # The queue page's Dispatch switch, on: saves a ::PrintQueue::DispatchResumption
    class ResumeDispatch < DispatchMutation
      description 'Resumes dispatch after pauseDispatch: the ready printers take their next print. Resuming while ' \
                  'not paused changes nothing.'

      private

      def operation_class = ::PrintQueue::DispatchResumption
    end
  end
end
