# typed: strict
# frozen_string_literal: true

# Groups OctoPrint's free-form state text ("Printing from SD", "Offline after error", ...) into a small,
# stable set of families that the UI and the printer actions can rely on.
#
#   PrinterStateFamily.for('Printing from SD') # => PrinterStateFamily::Printing
#   PrinterStateFamily.for('Something new')    # => PrinterStateFamily::Offline (and logs the text once)
class PrinterStateFamily < T::Enum
  extend T::Sig

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
  STATE_TEXTS = T.let(
    {
      Printing => ['Starting', 'Printing', 'Printing from SD', 'Sending file to SD', 'Resuming', 'Finishing'],
      Paused => %w[Pausing Paused],
      Cancelling => ['Cancelling'],
      Operational => ['Operational'],
      Connecting => ['Opening serial connection', 'Detecting serial connection', 'Connecting'],
      Error => ['Error', 'Offline after error'],
      Offline => %w[Offline Unknown]
    }.freeze,
    T::Hash[PrinterStateFamily, T::Array[String]]
  )

  # Longest prefixes first, so that "Offline after error" wins over "Offline"
  PREFIXES = T.let(
    STATE_TEXTS
      .flat_map { |family, texts| texts.map { |text| [text.downcase, family] } }
      .sort_by { |prefix, _family| -prefix.length }
      .freeze,
    T::Array[[String, PrinterStateFamily]]
  )

  # Families in which OctoPrint is connected to the printer and can report temperatures
  CONNECTED = T.let([Printing, Paused, Cancelling, Operational].freeze, T::Array[PrinterStateFamily])

  # Bounds the memory used to log each unknown state text only once
  MAX_LOGGED_UNKNOWN_TEXTS = 100

  @logged_unknown_texts = T.let(Concurrent::Set.new, Concurrent::Set)

  class << self
    extend T::Sig

    # Maps an OctoPrint state text to its family. Unmatched text maps to Offline and is logged (once per text).
    sig { params(state_text: T.nilable(String)).returns(PrinterStateFamily) }
    def for(state_text)
      text = state_text.to_s.strip.downcase
      return Offline if text.empty?

      match = PREFIXES.find { |prefix, _family| text.start_with?(prefix) }
      return match.last if match

      log_unknown(T.must(state_text))
      Offline
    end

    private

    sig { params(state_text: String).void }
    def log_unknown(state_text)
      @logged_unknown_texts.clear if @logged_unknown_texts.size >= MAX_LOGGED_UNKNOWN_TEXTS
      return unless @logged_unknown_texts.add?(state_text)

      Rails.logger.warn("[PrinterStateFamily] Unknown OctoPrint state #{state_text.inspect}, treating it as OFFLINE")
    end
  end

  # Whether OctoPrint is connected to the printer (temperatures are available, commands can be sent)
  sig { returns(T::Boolean) }
  def connected?
    CONNECTED.include?(self)
  end
end
