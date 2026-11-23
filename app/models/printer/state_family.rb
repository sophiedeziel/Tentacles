# typed: strict
# frozen_string_literal: true

class Printer
  # Groups OctoPrint's free-form state text ("Printing from SD", "Offline after error", ...) into a small,
  # stable set of families that the UI and the printer actions can rely on.
  #
  #   Printer::StateFamily.for('Printing from SD') # => Printer::StateFamily::Printing
  #   Printer::StateFamily.for('Something new')    # => Printer::StateFamily::Offline (and logs the text once)
  #
  # PrusaLink reports one of a few fixed states instead: see .for_prusalink.
  class StateFamily < T::Enum
    enums do
      Printing = new('PRINTING')
      Paused = new('PAUSED')
      Cancelling = new('CANCELLING')
      Operational = new('OPERATIONAL')
      Connecting = new('CONNECTING')
      Error = new('ERROR')
      Offline = new('OFFLINE')
    end

    # OctoPrint state texts per family. A state text belongs to a family when it starts with one of these.
    #
    # Built from OctoPrint's `MachineCom#getStateString` (src/octoprint/util/comm.py) in the current release (1.11),
    # plus the texts of older releases still in use (1.3/1.4: "Opening serial port", "Detecting baudrate",
    # "Error: <message>", "Offline (Error: <message>)") and the "Closed" connection state.
    STATE_TEXTS = {
      # "Starting" also covers "Starting print from SD" and "Starting to send file to SD"
      Printing => ['Starting', 'Printing', 'Printing from SD', 'Sending file to SD', 'Transferring file to SD',
                   'Resuming', 'Finishing'],
      Paused => %w[Pausing Paused],
      Cancelling => ['Cancelling'],
      Operational => ['Operational'],
      Connecting => ['Opening serial connection', 'Opening serial port', 'Detecting serial connection',
                     'Detecting serial port', 'Detecting baudrate', 'Connecting'],
      # "Error" also covers the older "Error: <message>"
      Error => ['Error', 'Offline after error', 'Offline (Error'],
      # "Unknown" covers Printer::Status::UNKNOWN_STATE_TEXT as well as OctoPrint's "Unknown State (<n>)"
      Offline => ['Offline', 'Closed', 'Unknown State', 'Unknown']
    }.freeze #: Hash[Printer::StateFamily, Array[String]]

    # Longest prefixes first, so that "Offline after error" wins over "Offline"
    PREFIXES = STATE_TEXTS
               .flat_map { |family, texts| texts.map { |text| [text.downcase, family] } }
               .sort_by { |prefix, _family| -prefix.length }
               .freeze #: Array[[String, Printer::StateFamily]]

    # PrusaLink's `printer.state` per family. ATTENTION (the printer waits for the user, e.g. after a filament
    # runout) depends on the job, see .for_prusalink.
    PRUSALINK_STATES = {
      'PRINTING' => Printing,
      'PAUSED' => Paused,
      'IDLE' => Operational,
      'READY' => Operational,
      'FINISHED' => Operational,
      'STOPPED' => Operational,
      'BUSY' => Operational,
      'ERROR' => Error
    }.freeze #: Hash[String, Printer::StateFamily]

    # Families in which OctoPrint is connected to the printer and can report temperatures
    CONNECTED = [Printing, Paused, Cancelling, Operational].freeze #: Array[Printer::StateFamily]

    # Families in which a print is under way: its job stays active and the spooler keeps monitoring it
    IN_PROGRESS = [Printing, Paused, Cancelling].freeze #: Array[Printer::StateFamily]

    # Bounds the memory used to log each unknown state text only once
    MAX_LOGGED_UNKNOWN_TEXTS = 100

    @logged_unknown_texts = Concurrent::Set.new #: Concurrent::Set

    class << self
      # Maps an OctoPrint state text to its family. Unmatched text maps to Offline and is logged (once per text).
      #: (String? state_text) -> Printer::StateFamily
      def for(state_text)
        text = state_text.to_s.strip.downcase
        return Offline if text.empty?

        match = PREFIXES.find { |prefix, _family| text.start_with?(prefix) }
        return match.last if match

        log_unknown('OctoPrint', T.must(state_text))
        Offline
      end

      # Maps a PrusaLink `printer.state` ("PRINTING", "ATTENTION", ...) to its family. `job` tells whether PrusaLink
      # reports a job: ATTENTION is PAUSED during a job, ERROR otherwise. Unknown states map to Offline and are
      # logged (once per state).
      #
      #   Printer::StateFamily.for_prusalink('ATTENTION', job: true)  # => Printer::StateFamily::Paused
      #   Printer::StateFamily.for_prusalink('ATTENTION', job: false) # => Printer::StateFamily::Error
      #: (String? state, job: bool) -> Printer::StateFamily
      def for_prusalink(state, job:)
        return Offline if state.blank?
        return job ? Paused : Error if state == 'ATTENTION'

        family = PRUSALINK_STATES[state]
        return family if family

        log_unknown('PrusaLink', state)
        Offline
      end

      private

      #: (String backend, String state_text) -> void
      def log_unknown(backend, state_text)
        @logged_unknown_texts.clear if @logged_unknown_texts.size >= MAX_LOGGED_UNKNOWN_TEXTS
        return unless @logged_unknown_texts.add?([backend, state_text])

        Rails.logger.warn("[Printer::StateFamily] Unknown #{backend} state #{state_text.inspect}, " \
                          'treating it as OFFLINE')
      end
    end

    # Whether OctoPrint is connected to the printer (temperatures are available, commands can be sent)
    #: -> bool
    def connected?
      CONNECTED.include?(self)
    end

    # Whether a print is under way (printing, paused or being cancelled)
    #: -> bool
    def in_progress?
      IN_PROGRESS.include?(self)
    end
  end
end
