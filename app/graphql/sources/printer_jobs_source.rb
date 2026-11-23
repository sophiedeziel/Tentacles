# typed: true
# frozen_string_literal: true

module Sources
  # Batches the queue lookups of a query (is there an enqueued / active job, how many are enqueued, which one is
  # next) into a single SQL query: one row per printer and status, with its count and its first job.
  #
  #   dataloader.with(Sources::PrinterJobsSource).load(printer.id) # => Sources::PrinterJobsSource::Queue
  class PrinterJobsSource < GraphQL::Dataloader::Source
    STATUSES = %w[enqueued active].freeze

    # A printer's queue, read-only
    class Queue
      # How many jobs wait in the printer's queue
      #: Integer
      attr_reader :enqueued_count

      # The first job of the queue (Printer#next_job), nil when the queue is empty
      #: ::Printer::Job?
      attr_reader :next_job

      # Whether the printer has a job under way
      #: bool
      attr_reader :active

      #: (enqueued_count: Integer, next_job: ::Printer::Job?, active: bool) -> void
      def initialize(enqueued_count:, next_job:, active:)
        @enqueued_count = enqueued_count
        @next_job = next_job
        @active = active
        freeze
      end

      # Whether the printer's queue has at least one job
      #: -> bool
      def enqueued?
        enqueued_count.positive?
      end
    end

    #: (Array[Integer] printer_ids) -> Array[Queue]
    def fetch(printer_ids)
      firsts = first_jobs(printer_ids).index_by { |job| [job.printer_id, job.status] }
      printer_ids.map do |printer_id|
        next_job = firsts[[printer_id, 'enqueued']]
        Queue.new(enqueued_count: next_job ? next_job['status_count'].to_i : 0, next_job:,
                  active: firsts.key?([printer_id, 'active']))
      end
    end

    private

    # The first job (in queue order: created_at, then id) of each printer and status, with the number of jobs of
    # that printer and status in `status_count`
    #: (Array[Integer] printer_ids) -> Array[::Printer::Job]
    def first_jobs(printer_ids)
      ranked = ::Printer::Job.where(printer_id: printer_ids, status: STATUSES).select(
        'printer_jobs.*',
        'COUNT(*) OVER (PARTITION BY printer_id, status) AS status_count',
        'ROW_NUMBER() OVER (PARTITION BY printer_id, status ORDER BY created_at, id) AS status_rank'
      )
      ::Printer::Job.from(ranked, :printer_jobs).where(status_rank: 1).to_a
    end
  end
end
