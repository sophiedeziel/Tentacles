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

    field :files, [FileType], null: false,
                              description: 'files'
    def files
      FileManager::File.all
    end
  end
end
