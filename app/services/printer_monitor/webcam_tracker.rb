# typed: true
# frozen_string_literal: true

module PrinterMonitor
  # Caches a printer's webcam settings, which rarely change: they are fetched on (re)connection, then every
  # 10 minutes. The last known camera is kept when the settings can't be read (e.g. the API key lacks SETTINGS_READ).
  class WebcamTracker
    extend T::Sig
    include Logging

    REFRESH_EVERY = T.let(10.minutes, ActiveSupport::Duration)

    sig { override.returns(Printer) }
    attr_reader :printer

    sig { returns(PrinterStatus::Camera) }
    attr_reader :camera

    sig { params(printer: Printer, reader: OctoprintReader).void }
    def initialize(printer, reader)
      @printer = printer
      @reader = reader
      @camera = T.let(PrinterStatus::Camera.new, PrinterStatus::Camera)
      @fetched_at = T.let(nil, T.nilable(PrinterStatus::TimeLike))
    end

    # Fetches the webcam settings when they are due. Never raises an OctoPrint error or a bad response error.
    sig { void }
    def refresh
      return unless due?

      @fetched_at = Time.current
      @camera = @reader.camera
    # A server that isn't OctoPrint can answer with HTML (JSON::ParserError) or without an `error` key (KeyError)
    rescue Octoprint::Exceptions::Error, JSON::ParserError, KeyError => e
      log_exception('Failed to read the webcam settings', e)
    end

    # Fetch the settings on the next refresh (e.g. once OctoPrint answers again)
    sig { void }
    def expire
      @fetched_at = nil
    end

    private

    sig { returns(T::Boolean) }
    def due?
      fetched_at = @fetched_at
      fetched_at.nil? || Time.current - fetched_at >= REFRESH_EVERY
    end
  end
end
