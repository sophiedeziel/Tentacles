# frozen_string_literal: true

module Types
  class EnqueuedJob < Base::Object
    implements Types::Job
    description 'A job enqueued on Tentacles.'

    field :executable, Types::File, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
