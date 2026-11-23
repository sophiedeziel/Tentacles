# typed: true
# frozen_string_literal: true

class Printer
  module Monitor
    # Caches a printer's webcam settings, which rarely change: they are fetched on (re)connection, then every
    # 10 minutes. The last known camera is kept when the settings can't be read (e.g. the API key lacks SETTINGS_READ).
    #
    #   webcam = Printer::Monitor::WebcamTracker.new(printer:, reader: Printer::Monitor::Reader.for(printer))
    #   webcam.refresh # reads the settings when they're due
    #   webcam.camera  # => Printer::Status::Camera, disabled until the settings were read once
    #   webcam.expire  # read them on the next refresh
    #
    # Owned by one Worker, and only touched from its thread.
    class WebcamTracker < ApplicationModel
      include Logging

      REFRESH_EVERY = 10.minutes #: ActiveSupport::Duration

      attribute :printer
      # The printer's Reader (see Reader#camera)
      attribute :reader
      # The last known camera
      attribute :camera, ModelType.new(Printer::Status::Camera), default: -> { Printer::Status::Camera.new }
      # When the settings were last fetched, nil to fetch them on the next refresh
      attribute :fetched_at, TimeType.new

      # Fetches the webcam settings when they are due. Never raises a printer API error or a bad response error.
      #: -> void
      def refresh
        return unless due?

        # A TimeWithZone, which is_a?(Time): the generated RBI types the time attributes as Time
        self.fetched_at = T.cast(Time.current, Time)
        self.camera = reader.camera
      # A server that isn't OctoPrint can answer with HTML (JSON::ParserError) or without an `error` key (KeyError)
      rescue Printer::Backend::Error, JSON::ParserError, KeyError => e
        log_exception('Failed to read the webcam settings', e)
      end

      # Fetch the settings on the next refresh (e.g. once OctoPrint answers again)
      #: -> void
      def expire
        self.fetched_at = nil
      end

      private

      #: -> bool
      def due?
        last_fetch = fetched_at
        last_fetch.nil? || Time.current - last_fetch >= REFRESH_EVERY
      end
    end
  end
end
