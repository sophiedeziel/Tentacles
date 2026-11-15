# typed: true
# frozen_string_literal: true

module Sources
  # Batches the "does this printer have enqueued / active jobs?" lookups of a query into a single grouped SQL query.
  #
  #   dataloader.with(Sources::PrinterJobsSource).load(printer.id) # => Sources::PrinterJobsSource::Presence
  class PrinterJobsSource < GraphQL::Dataloader::Source
    extend T::Sig

    class Presence < T::Struct
      # Whether the printer's queue has at least one job
      const :enqueued, T::Boolean
      # Whether the printer has a job under way
      const :active, T::Boolean
    end

    sig { params(printer_ids: T::Array[Integer]).returns(T::Array[Presence]) }
    def fetch(printer_ids)
      counts = ::Printer::Job.where(printer_id: printer_ids, status: %w[enqueued active])
                             .group(:printer_id, :status).count
      printer_ids.map do |printer_id|
        Presence.new(enqueued: counts.key?([printer_id, 'enqueued']), active: counts.key?([printer_id, 'active']))
      end
    end
  end
end
