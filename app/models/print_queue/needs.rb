# typed: true
# frozen_string_literal: true

module PrintQueue
  # What an entry needs from a printer: read from its file's G-code summary each time (no snapshot: a recomputed
  # summary changes the needs), plus the colour the entry asks for. nil is Not known, and a value the file doesn't
  # state is never held against a printer (see PrintQueue::HardLimitations and PrintQueue::Fit).
  #
  #   needs = PrintQueue::Needs.of(entry)
  #   needs.runnable?        # => false while the summary is pending (or a .gcode has none yet)
  #   needs.known?           # => true once the summary is ready; false when it failed or the file isn't G-code
  #   needs.tools            # => [PrintQueue::Needs::Tool(tool: 0, material: "PLA")]
  #   needs.colour           # => "Black", nil for Any colour
  #   needs.width            # => 123.09 (mm, along X), depth along Y, height (max Z)
  #   needs.tool_count       # => 1
  #   needs.filament_changes # => [{ "line" => 1234, "z" => 5.4, "layer" => 27 }]: carried, no rule reads it yet
  class Needs < ApplicationModel
    # The filament one tool needs: `tool` is 0-based (T0), `material` a key of Filament::MATERIALS (nil: Not known)
    class Tool < ApplicationModel
      attribute :tool, :integer
      attribute :material, :string

      # @override
      #: -> bool
      def readonly? = true
    end

    # Array[PrintQueue::Needs::Tool], in tool order
    attribute :tools, default: -> { [] }
    attribute :colour, :string
    attribute :width, :decimal
    attribute :depth, :decimal
    attribute :height, :decimal
    attribute :tool_count, :integer
    # Array[Hash[String, untyped]], the summary's M600 list
    attribute :filament_changes, default: -> { [] }
    attribute :known, :boolean, default: false
    attribute :runnable, :boolean, default: true

    # The needs of an entry, from its item's gcode_summary (preload `item: [{ gcode_summary: :tools }, ...]` for many)
    #: (PrintQueue::Job job) -> PrintQueue::Needs
    def self.of(job)
      item = job.item #: as !nil
      summary = item.gcode_summary
      # Not read yet: it will be (a .gcode without a summary is scheduled when it's stored)
      return new(colour: job.colour, runnable: false) if summary.nil? ? item.gcode? : summary.pending?
      # Failed, or not G-code: every value Not known
      return new(colour: job.colour) unless summary&.ready?

      read(summary, colour: job.colour)
    end

    #: (Library::GcodeSummary summary, colour: String?) -> PrintQueue::Needs
    def self.read(summary, colour:)
      footprint = summary.footprint
      new(colour:, known: true, width: footprint&.width, depth: footprint&.depth, height: summary.max_z,
          tool_count: summary.tool_count, filament_changes: summary.filament_changes,
          tools: summary.tools.map { |tool| Tool.new(tool: tool.tool, material: tool.material) })
    end
    private_class_method :read

    # Whether the summary was read (ready): false when it failed or the file isn't G-code
    #: -> bool
    def known? = known == true

    # Whether the entry can be dispatched as far as its file goes: false while its summary is pending
    #: -> bool
    def runnable? = runnable == true

    # Read from the summary: nothing to save
    # @override
    #: -> bool
    def readonly? = true
  end
end
