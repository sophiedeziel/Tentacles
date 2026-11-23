# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # Saves a ::PrintQueue::Hold
    class HoldPrintJob < PrintJobMutation
      description 'Holds a print job: it keeps its place, but no copy starts until releasePrintJob. Copies already ' \
                  'printing go on. Holding a held print job changes nothing.'

      private

      def operation_for(job) = ::PrintQueue::Hold.new(job:)
    end
  end
end
