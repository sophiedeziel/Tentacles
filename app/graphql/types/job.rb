# frozen_string_literal: true

module Types
  module Job
    include Base::Interface

    description 'A job that can be executed by a printer.'

    field :id, ID, null: false
    field :name, String, null: false
    field :status, String, null: true
    field :progress, Float, null: false

    orphan_types Types::OctoprintJob

    definition_methods do
      def resolve_type(object, _context)
        case object
        when ::Printer::Job
          Types::EnqueuedJob
        when Hash
          Types::OctoprintJob
        end
      end
    end
  end
end
