# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # Saves a ::PrintQueue::Release
    class ReleasePrintJob < PrintJobMutation
      description 'Releases a held print job (holdPrintJob): its copies can start again. Releasing a print job that ' \
                  'is not held changes nothing.'

      private

      def operation_for(job) = ::PrintQueue::Release.new(job:)
    end
  end
end
