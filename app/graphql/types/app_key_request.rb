# frozen_string_literal: true

module Types
  # Resolves from Printer::AppKeyRequest#payload. Never holds the API key. OctoPrint puts the request's app token in
  # the URL of its dialog (approvalUrl); it hands the key out once, to the first poll after approval: the job's.
  class AppKeyRequest < Base::Object
    description 'A request for an OctoPrint API key, which the user approves in OctoPrint. The key stays on the server.'

    field :id, ID, null: false, description: 'For printerAppKeyChanged and cancelPrinterAppKeyRequest'
    field :address, String, null: false, description: 'The address of the OctoPrint server, as requested'
    field :state, Types::AppKeyRequestState, null: false
    field :approval_url, Types::Url,
          null: true,
          description: "Where the user approves the request: OctoPrint's dialog for it when OctoPrint reports one, " \
                       "else OctoPrint's own page"
    field :printer, Types::Printer, null: true, description: 'The printer added with the key, when ADDED'
    field :error, String, null: true, description: 'What went wrong, when FAILED'
  end
end
