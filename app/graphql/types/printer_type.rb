module Types
  class PrinterType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :octoprint_uri, String, null: true
    field :octoprint_key, String, null: true
    field :octoprint_version, String, null: true
    def octoprint_version
      object.octoprint_version&.text
    end
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end