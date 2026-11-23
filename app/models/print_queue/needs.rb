# typed: true
# frozen_string_literal: true

module PrintQueue
  # What an entry needs from a printer: read from its file's G-code summary each time (no snapshot: a recomputed
  # summary changes the needs), plus the material and colour the entry asks for. nil is Not known, and a value the file
  # doesn't state is never held against a printer (see PrintQueue::HardLimitations and PrintQueue::Fit).
  #
  # The entry's material replaces the summary's for a file of one tool (or none known): the person chose it, so it's
  # known even when the summary failed. A file of several tools keeps its summary's materials (one per tool is
  # phase 9). An entry without a material needs the summary's.
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
    # The Library::GcodeSummary::Footprint its width and depth come from (nil when no box is known), for display
    attribute :footprint
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
      asked = asked_tools(job.material)
      # Not read yet: it will be (a .gcode without a summary is scheduled when it's stored)
      return new(colour: job.colour, tools: asked, runnable: false) if summary.nil? ? item.gcode? : summary.pending?
      # Failed, or not G-code: every value Not known, but the material asked for
      return new(colour: job.colour, tools: asked) unless summary&.ready?

      read(summary, colour: job.colour, material: job.material)
    end

    #: (Library::GcodeSummary summary, colour: String?, material: String?) -> PrintQueue::Needs
    def self.read(summary, colour:, material:)
      footprint = summary.footprint
      new(colour:, known: true, footprint:, width: footprint&.width, depth: footprint&.depth, height: summary.max_z,
          tool_count: summary.tool_count, filament_changes: summary.filament_changes,
          tools: tools_of(summary, material))
    end
    private_class_method :read

    # The summary's tools, the material asked for replacing the material of a file of one tool
    #: (Library::GcodeSummary summary, String? material) -> Array[PrintQueue::Needs::Tool]
    def self.tools_of(summary, material)
      tools = summary.tools.to_a
      single = tools.size <= 1 && summary.tool_count.to_i <= 1
      return asked_tools(material, tool: tools.first&.tool || 0) if material && single

      tools.map { |tool| Tool.new(tool: tool.tool, material: tool.material) }
    end
    private_class_method :tools_of

    # The tool a material asked for is needed on (T0 unless given), none without a material
    #: (String? material, ?tool: Integer) -> Array[PrintQueue::Needs::Tool]
    def self.asked_tools(material, tool: 0) = material ? [Tool.new(tool:, material:)] : []
    private_class_method :asked_tools

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
