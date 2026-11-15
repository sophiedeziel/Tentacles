# frozen_string_literal: true

module Types
  class PrinterIdentity < Base::Object
    description "What a printer's server says about itself, read with the credentials of a printer to add"

    field :name, String, null: true, description: "The printer's name, to suggest as the name of the printer"
    field :version, String, null: true, description: 'The server and its version, e.g. "PrusaLink 2.1.2"'
  end
end
