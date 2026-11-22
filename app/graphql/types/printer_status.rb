# frozen_string_literal: true

module Types
  # Resolves ::Printer::Status snapshots (written to Redis by the printer monitor)
  class PrinterStatus < Base::Object
    description 'Live state of a printer, as last reported by the printer monitor. Nullable fields are null when ' \
                "the printer's server has no value (not printing, or not connected)."
    default_broadcastable true

    field :state_family, Types::PrinterStateFamily, null: false
    field :state_text, String, null: false,
                               description: %(State as reported by the printer's server, e.g. "Printing from SD")
    field :server_reachable, Boolean,
          null: false, method: :server_reachable?,
          description: "Whether the printer's server (OctoPrint, PrusaLink) answered the monitor. OFFLINE with a " \
                       'reachable server means the server is up but not connected to the printer. False until the ' \
                       'monitor reports on the printer'
    field :error_text, String, null: true, description: 'Only in ERROR'
    field :file_name, String, null: true, description: 'File of the current job, null when no job is loaded'
    field :progress, Integer, null: true, description: 'Completion of the current job, 0 to 100'
    field :print_time_left, GraphQL::Types::ISO8601Duration,
          null: true, description: 'Estimated time left for the current job, rounded to 1 minute (e.g. "PT52M")'
    field :hotend, Types::TemperatureStatus, null: true, description: 'Null when the server is disconnected'
    field :bed, Types::TemperatureStatus, null: true, description: 'Null when the server is disconnected'
    field :camera, Types::PrinterCamera, null: false
    # Snapshots are only written when the status changes, so this is only up to date when OFFLINE
    field :last_seen_at, GraphQL::Types::ISO8601DateTime,
          null: true, description: "Last time the monitor reached the printer's server (meaningful when OFFLINE)"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When the status last changed'

    def progress
      object.progress&.round&.clamp(0, 100)
    end

    def print_time_left
      seconds = object.print_time_left
      seconds && ActiveSupport::Duration.build([(seconds / 60.0).round, 0].max * 60)
    end

    def hotend
      temperature(object.hotend)
    end

    def bed
      temperature(object.bed)
    end

    # Printers the monitor hasn't reported on yet have no snapshot time: their placeholder is as fresh as the query
    def updated_at
      object.updated_at || object.last_seen_at || Time.current
    end

    private

    # Without a current reading there's nothing to show
    def temperature(temperature)
      temperature if temperature&.actual
    end
  end
end
