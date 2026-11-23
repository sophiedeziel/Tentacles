# typed: true
# frozen_string_literal: true

module PrintQueue
  # How an entry fits a printer, from the entry's PrintQueue::Needs, the printer (its specs and preloaded
  # loaded_filaments) and its Printer::Status snapshot (nil when it has none), all passed in: no Redis read, and no
  # query once loaded_filaments is loaded.
  #
  #   fit = PrintQueue::Fit.new(needs: entry.needs, printer:, status:)
  #   fit.result  # => :after_filament_change
  #   fit.reasons # => [PrintQueue::Reason(code: :wrong_material, message: "Needs PLA. PETG is loaded here")]
  #
  # The first that applies wins:
  #
  # | Result                   | When                                                  | Reasons                       |
  # |--------------------------|-------------------------------------------------------|-------------------------------|
  # | `:cannot`                | a hard limitation (PrintQueue::HardLimitations)       | the limitations               |
  # | `:after_reconnect`       | offline: no snapshot, or Offline, Connecting or Error | :offline, filament changes    |
  # | `:after_filament_change` | a slot doesn't have the filament asked for            | the filament changes          |
  # | `:ready`                 | otherwise                                             | what was matched              |
  #
  # Filament: tool n uses slot n + 1, and only the slots up to `filament_slots` are checked (multi-filament is
  # phase 9). The entry's colour (nil: Any colour) is asked of each checked tool. A file with no tool known asks for
  # tool 0 with its material Not known. Per tool:
  # - known material: the slot's filament must match it and the colour (Printer::LoadedFilament#matches?):
  #   :filament_matches, else :no_filament, :wrong_material or :wrong_colour.
  # - material Not known, a colour asked: the slot's filament must be of that colour (any material).
  # - material Not known, Any colour: nothing asked (:any_filament), even of an empty slot.
  class Fit < ApplicationModel
    RESULTS = %i[ready after_filament_change after_reconnect cannot].freeze #: Array[Symbol]
    # The filament checks that ask for no change
    MATCHES = %i[filament_matches any_filament].freeze #: Array[Symbol]

    attribute :needs
    attribute :printer
    attribute :status

    # Why a printer is offline for the queue, or nil when it's connected (Printing, Paused, Cancelling or Operational).
    # Shared with PrintQueue::Readiness.
    #: (Printer::Status? status) -> PrintQueue::Reason?
    def self.offline_reason(status)
      return PrintQueue::Reason.new(code: :offline, message: 'Offline') if status.nil?

      family = status.state_family #: as !nil
      return if family.connected?

      message = family.serialize.capitalize # "Offline", "Connecting" or "Error"
      error = status.error_text if family == Printer::StateFamily::Error
      PrintQueue::Reason.new(code: :offline, message: [message, error.presence].compact.join(': '))
    end

    # One of RESULTS
    #: -> Symbol
    def result
      answer.first
    end

    # Why: never empty
    #: -> Array[PrintQueue::Reason]
    def reasons
      answer.last
    end

    #: -> bool
    def ready? = result == :ready

    #: -> bool
    def cannot? = result == :cannot

    # Whether the filament it needs is loaded: :ready, or :after_reconnect only because the printer is offline
    #: -> bool
    def filament_loaded? = ready? || (result == :after_reconnect && reasons.all? { |reason| reason.code == :offline })

    # The filament checks that ask for a change (:no_filament, :wrong_material, :wrong_colour), empty when none does.
    # Their messages are what the printer's page shows under Skipped by This Printer.
    #: -> Array[PrintQueue::Reason]
    def filament_changes
      filament_checks.reject { |check| MATCHES.include?(check.code) }
    end

    # @override
    #: -> bool
    def readonly? = true

    private

    #: -> [Symbol, Array[PrintQueue::Reason]]
    def answer
      @answer ||= decide
    end

    #: -> [Symbol, Array[PrintQueue::Reason]]
    def decide
      limitations = PrintQueue::HardLimitations.new(needs:, printer:)
      return [:cannot, limitations.reasons] if limitations.any?

      offline = self.class.offline_reason(status)
      return [:after_reconnect, [offline, *filament_changes]] if offline
      return [:after_filament_change, filament_changes] if filament_changes.any?

      [:ready, filament_checks]
    end

    # One reason per checked tool
    #: -> Array[PrintQueue::Reason]
    def filament_checks
      @filament_checks ||= checked_tools.map { |tool| filament_check(tool) }
    end

    #: -> Array[PrintQueue::Needs::Tool]
    def checked_tools
      tools = needs.tools.presence || [PrintQueue::Needs::Tool.new(tool: 0)]
      tools.select { |tool| slot(tool) <= printer.filament_slots }
    end

    #: (PrintQueue::Needs::Tool tool) -> PrintQueue::Reason
    def filament_check(tool)
      material = tool.material
      colour = needs.colour
      return filament_reason(tool, :any_filament, 'Any filament') if material.nil? && colour.nil?

      loaded = loaded_filament(tool)
      if loaded.nil?
        return filament_reason(tool, :no_filament, "Needs #{asked(material, colour)}. No filament is loaded here")
      end

      loaded_check(tool, loaded, material, colour)
    end

    # What's loaded in the tool's slot against what's asked. A change says what's asked, then what's loaded: its
    # material alone when the material is what differs ("Needs PETG. PLA is loaded here"), with its colour otherwise
    # ("Needs PLA White. PLA Black is loaded here").
    #: (PrintQueue::Needs::Tool tool, Printer::LoadedFilament loaded, String? material, String? colour)
    #|   -> PrintQueue::Reason
    def loaded_check(tool, loaded, material, colour)
      if matches?(loaded, material, colour)
        return filament_reason(tool, :filament_matches, "Loaded #{loaded.material} #{loaded.colour} matches")
      end

      wrong_material = !material.nil? && loaded.material != material
      here = wrong_material ? loaded.material : "#{loaded.material} #{loaded.colour}"
      filament_reason(tool, wrong_material ? :wrong_material : :wrong_colour,
                      "Needs #{asked(material, colour)}. #{here} is loaded here")
    end

    # With a known material: Printer::LoadedFilament#matches? (and the colour, unless Any colour). With none: the colour
    #: (Printer::LoadedFilament loaded, String? material, String? colour) -> bool
    def matches?(loaded, material, colour)
      return loaded.matches?(material:, colour:) if material

      loaded.colour_key == Filament.colour_key(colour)
    end

    # "PLA Black", "PLA" or "Black"
    #: (String? material, String? colour) -> String
    def asked(material, colour) = [material, colour].compact.join(' ')

    #: (PrintQueue::Needs::Tool tool) -> Printer::LoadedFilament?
    def loaded_filament(tool)
      printer.loaded_filaments.find { |filament| filament.slot == slot(tool) }
    end

    # Tool n uses slot n + 1
    #: (PrintQueue::Needs::Tool tool) -> Integer
    def slot(tool) = tool.tool.to_i + 1

    # Names the slot when the printer has more than one
    #: (PrintQueue::Needs::Tool tool, Symbol code, String message) -> PrintQueue::Reason
    def filament_reason(tool, code, message)
      message = "Slot #{slot(tool)}: #{message}" if printer.filament_slots > 1
      PrintQueue::Reason.new(code:, message:)
    end
  end
end
