# frozen_string_literal: true

module Types
  class Printer < Base::Object
    # No field depends on the context, so printerStatusChanged can broadcast them
    default_broadcastable true

    field :id, ID, null: false
    field :name, String, null: false
    field :octoprint_uri, String, null: true
    field :octoprint_key, String, null: true
    field :octoprint_version, String, null: true
    def octoprint_version
      object.octoprint_version&.text || 'Unavailable'
    end
    field :job_status, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :jobs, Types::EnqueuedJob.connection_type, null: false
    field :jobs_count, Integer, null: false
    field :current_job, Types::Job, null: true

    field :status, Types::PrinterStatus, null: false,
                                         description: 'Live state, as last reported by the printer monitor'
    # Reads the monitor's snapshot from Redis (one MGET for all the printers of a query), never OctoPrint
    def status
      dataloader.with(Sources::PrinterStatusSource).load(object.id) ||
        ::PrinterStatus.unknown(printer_id: object.id, last_seen_at: object.last_seen_at)
    end

    field :can_start_next, Boolean,
          null: false, resolver_method: :can_start_next?,
          description: 'Whether startNextPrint would start the next job of the queue: the printer is OPERATIONAL ' \
                       '(as last reported by the printer monitor), its queue is not empty and it has no active job'
    # Batched: one Redis MGET and one grouped SQL query for all the printers of a query, never OctoPrint
    def can_start_next?
      status_request = dataloader.with(Sources::PrinterStatusSource).request(object.id)
      jobs_request = dataloader.with(Sources::PrinterJobsSource).request(object.id)
      state_family = status_request.load&.state_family || ::PrinterStateFamily::Offline
      jobs = jobs_request.load
      ::Printer.start_next_allowed?(state_family:, enqueued: jobs.enqueued?, active: jobs.active)
    end

    field :queued_count, Integer, null: false, description: 'How many jobs wait in the queue'
    # Batched with canStartNext: one SQL query for all the printers of a query
    def queued_count
      dataloader.with(Sources::PrinterJobsSource).load(object.id).enqueued_count
    end

    field :next_job, Types::EnqueuedJob, null: true, description: 'The next job of the queue, null when it is empty'
    # Batched: the same SQL query as queuedCount, then one query per association for the files
    def next_job
      dataloader.with(Sources::NextJobSource).load(object.id)
    end
  end
end
