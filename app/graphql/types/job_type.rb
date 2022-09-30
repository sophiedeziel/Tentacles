# frozen_string_literal: true

module Types
  class JobType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :status, String, null: true
    field :executable, Types::FileType, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :progress, Float, null: false
  end
end
