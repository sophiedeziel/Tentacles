# frozen_string_literal: true

module Types
  class FileType < Types::BaseObject
    field :id, ID, null: false
    field :filename, String, null: false
    field :notes, String, null: false
    field :filetype, String, null: false
    field :filesize, Integer, null: false
    field :is_archived, Boolean, null: false, method: :archived?
    field :is_deleted, Boolean, null: false, method: :deleted?
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :archived_at, GraphQL::Types::ISO8601DateTime, null: true
    field :download_url, String, null: false
    field :top_file_comments, String, null: true
    field :file_content, String, null: true
  end
end
