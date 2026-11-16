# frozen_string_literal: true

module Types
  class PrinterCamera < Base::Object
    description "A printer's webcam, as configured in its server (OctoPrint, ...)"
    default_broadcastable true

    field :enabled, Boolean, null: false, description: "Whether the webcam is enabled in the printer's server"
    field :stream_url, Types::Url, null: true, description: 'Absolute URL of the webcam stream'
  end
end
