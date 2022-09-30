# frozen_string_literal: true

module Types
  class PrinterType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :octoprint_uri, String, null: true
    field :octoprint_key, String, null: true
    field :octoprint_version, String, null: true
    field :job_status, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :jobs, Types::JobType.connection_type, null: false
    field :jobs_count, Integer, null: false
  end
end
