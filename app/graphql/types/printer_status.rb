# frozen_string_literal: true

module Types
  # Resolves ::PrinterStatus snapshots (written to Redis by the printer monitor)
  class PrinterStatus < Base::Object
    description 'Live state of a printer, as last reported by the printer monitor'
    default_broadcastable true

    field :state_family, Types::PrinterStateFamily, null: false
    field :state_text, String, null: false, description: 'State as reported by OctoPrint'
    field :error_text, String, null: true
    field :file_name, String, null: true, description: 'File of the current job'
    field :progress, Float, null: true, description: 'Completion of the current job, in percent'
    field :print_time_left, Integer, null: true, description: 'Estimated time left for the current job, in seconds'
    field :hotend, Types::PrinterTemperature, null: true
    field :bed, Types::PrinterTemperature, null: true
    field :camera, Types::PrinterCamera, null: false
    # Snapshots are only written when the status changes, so this is only up to date when OFFLINE
    field :last_seen_at, GraphQL::Types::ISO8601DateTime,
          null: true, description: 'Last time the monitor reached OctoPrint (meaningful when OFFLINE)'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true, description: 'When the status last changed'
  end
end
