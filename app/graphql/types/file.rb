# frozen_string_literal: true

module Types
  class File < Base::Object
    # Broadcastable: printerStatusChanged can select Printer.nextJob's file name
    field :id, ID, null: false, broadcastable: true
    field :filename, String, null: false, broadcastable: true
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
    field :gcode_analysis, Types::GcodeAnalysis, null: true
    field :labels, Label.connection_type, null: false
  end
end
