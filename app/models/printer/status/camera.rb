# typed: true
# frozen_string_literal: true

class Printer
  class Status < ApplicationModel
    # The webcam of the snapshot, as configured in the printer's server
    #
    #   Printer::Status::Camera.new(enabled: true, stream_url: 'http://octopi.local/webcam/?action=stream')
    class Camera < ApplicationModel
      include Equality
      include Serialization

      attribute :enabled, :boolean, default: false
      # Absolute URL of the webcam stream
      attribute :stream_url, :string
    end
  end
end
