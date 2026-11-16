# frozen_string_literal: true

module Types
  class PrinterJob < Base::Object
    implements Types::Job
    description "The job a printer reports when the queue has no active job, e.g. a print started from the printer's " \
                'screen.'
  end
end
