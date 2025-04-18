# frozen_string_literal: true

module RootOperations
  class Query < Base::Object
    # Add `node(id: ID!) and `nodes(ids: [ID!]!)`
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :printers, [Types::Printer], null: false,
                                       description: 'asdf'
    def printers
      ::Printer.all
    end

    field :printer, Types::Printer, null: true do
      argument :id, ID, required: true
    end
    def printer(id:)
      ::Printer.find(id)
    end

    field :files, [Types::File], null: false do
      description 'files'
    end
    def files
      ::FileRecord.includes(:labels).with_attached_file
    end

    field :file, Types::File, null: true do
      argument :id, ID, required: true
    end
    def file(id:)
      ::FileRecord.find_by(id: id)
    end

    field :labels, Types::Label.connection_type, null: false do
      description 'labels'
    end
    def labels
      ::Label.all
    end

    field :label, Types::Label, null: true do
      argument :id, ID, required: true
    end
    def label(id:)
      ::Label.find_by(id: id)
    end

    field :search_network_printers, [String], null: true
    def search_network_printers
      ::PrinterScanner.new.call
    end

    field :octoprint_name, String, null: true do
      argument :octoprint_uri, String, required: true
      argument :octoprint_key, String, required: true
    end
    def octoprint_name(octoprint_uri:, octoprint_key:)
      client = Octoprint::Client.new(host: octoprint_uri, api_key: octoprint_key)
      client.use do
        connection = Octoprint::Connection.get
        default_profile = connection.options.printer_profiles.find { |p| p[:id] == '_default' }
        default_profile[:name]
      end
    end
  end
end
