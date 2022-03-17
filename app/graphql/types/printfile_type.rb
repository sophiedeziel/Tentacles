module Types
  class PrintfileType < Types::BaseObject
    field :id, ID, null: false
    field :filename, String, null: false
    field :notes, String, null: false
    field :filetype, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end