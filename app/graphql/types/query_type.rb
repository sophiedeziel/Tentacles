module Types
  class QueryType < Types::BaseObject
    # Add `node(id: ID!) and `nodes(ids: [ID!]!)`
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :printers, [PrinterType], null: false,
      description: "asdf"
    def printers
      Printer.all
    end

    field :printfiles, [PrintfileType], null: false, 
      description: "files"
    def printfiles
      Printfile.all
    end
  end
end
