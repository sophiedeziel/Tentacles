# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    # Add `node(id: ID!) and `nodes(ids: [ID!]!)`
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :printers, [PrinterType], null: false,
                                    description: 'asdf'
    def printers
      Printer.all
    end

    field :files, [FileType], null: false do
      description 'files'
    end
    def files
      FileManager::File.with_attached_file
    end

    field :file, FileType, null: true do
      argument :id, ID, required: true
    end
    def file(id:)
      FileManager::File.find(id)
    end
  end
end
