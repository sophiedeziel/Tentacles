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
  end
end
