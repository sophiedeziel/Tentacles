# frozen_string_literal: true

module Types
  class FileType < Types::BaseObject
    field :id, ID, null: false
    field :filename, String, null: false
    field :notes, String, null: false
    field :filetype, String, null: false
    field :filesize, Integer, null: false
    field :is_archived, Boolean, null: false
    def is_archived
      !object.is_not_archived
    end
    field :is_deleted, Boolean, null: false
    def is_deleted
      false
    end
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :archived_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
