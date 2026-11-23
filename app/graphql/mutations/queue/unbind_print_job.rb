# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # Release to Other Printers: saves a ::PrintQueue::PrinterBindingRelease
    class UnbindPrintJob < PrintJobMutation
      description 'Release to Other Printers: the copies of a same-printer batch go to any printer again ' \
                  '(samePrinter false, boundPrinter null)'

      private

      def operation_for(job) = ::PrintQueue::PrinterBindingRelease.new(job:)
    end
  end
end
