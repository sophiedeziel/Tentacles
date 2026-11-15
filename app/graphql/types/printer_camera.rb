# frozen_string_literal: true

module Types
  class PrinterCamera < Base::Object
    description "A printer's webcam, as configured in OctoPrint"
    default_broadcastable true

    field :enabled, Boolean, null: false, description: 'Whether the webcam is enabled in OctoPrint'
    field :stream_url, String, null: true, description: 'Absolute URL of the webcam stream'
  end
end
