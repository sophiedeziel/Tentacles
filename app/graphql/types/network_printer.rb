# frozen_string_literal: true

module Types
  # Resolves from a Hash: { address:, url:, printer: }
  class NetworkPrinter < Base::Object
    description 'An OctoPrint server found on the local network: it answers the probe of the Application Keys plugin'

    field :address, String, null: false, description: 'Its IP address, e.g. "192.168.1.57"'
    field :url, String, null: false, description: 'The URL of its web interface, e.g. "http://192.168.1.57/"'
    field :printer, Types::Printer, null: true,
                                    description: 'The saved printer at that address (same host in its URL), null ' \
                                                 'when it is not added yet'
  end
end
