# frozen_string_literal: true

module Types
  # A ::Printer::LoadedFilament: the filament loaded in one slot of a printer
  class LoadedFilament < Base::Object
    description 'The filament loaded in one slot of a printer'
    # Pushed with the printer by printerStatusChanged: no field depends on the context
    default_broadcastable true

    field :slot, Integer, null: false, description: 'The slot, from 1. Every printer has one slot for now.'
    field :material, String, null: false, description: 'One of filamentMaterials, e.g. "PLA"'
    field :colour, String, null: false, description: 'As typed, for display, e.g. "Galaxy Black"'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: 'When the spool was last changed'
    field :waiting_jobs_asking_count, Integer,
          null: false,
          description: 'How many print jobs with copies left to start (held ones included) ask for exactly this ' \
                       'material and colour, whatever printer they are limited to. Jobs asking for Any colour are ' \
                       'not counted, though they print with it. 0 while the global queue is off.'

    # Batched: read once per query from the queue, whatever the number of filaments
    def waiting_jobs_asking_count
      return 0 unless ::PrintQueue.enabled?

      dataloader.with(Sources::FilamentDemandSource).load(:current).count_for(object)
    end
  end
end
