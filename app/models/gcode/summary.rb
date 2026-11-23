# typed: true
# frozen_string_literal: true

module Gcode
  # What a G-code file needs to print: the time, the filament per tool, the footprint, the tool changes and the M600
  # filament changes. Read once, streamed, keeping counters only (unlike Gcode::Analysis, which keeps every line it
  # finds for the editor). Stored as a Library::GcodeSummary.
  #
  #   summary = Gcode::Summary.read(io)    # any IO of G-code text
  #   summary = Gcode::Summary.read_file(item.file) # an Active Storage attachment
  #   summary.slicer        # => "PrusaSlicer"
  #   summary.print_seconds # => 1828, or nil when Not known
  #   summary.tools.first   # => a Gcode::Summary::Tool (PLA, 2.63 g, 882.3 mm)
  #
  # Only PrusaSlicer's and Cura's comments are read (see Gcode::Summary::SlicerValues). For a file from any other
  # slicer, only what the moves tell is known: the footprint, the tools that extrude, the tool and filament changes.
  # A missing or malformed value is nil (Not known) and never fails the read; a line that doesn't parse is skipped.
  # Raises Gcode::Summary::Unreadable for a file that isn't G-code text (binary G-code included).
  class Summary < ApplicationModel
    # Bump it when the values read change: `bin/rails gcode:reanalyse` reads again the files read by an older version
    VERSION = 1

    # The file isn't G-code text: its message is short enough to show
    class Unreadable < StandardError; end

    attribute :slicer, :string
    attribute :slicer_version, :string
    attribute :print_seconds, :integer
    # In mm: the box of the extruding moves (skirt, brim and prime line included), or the one the slicer states
    attribute :min_x, :decimal
    attribute :max_x, :decimal
    attribute :min_y, :decimal
    attribute :max_y, :decimal
    attribute :max_z, :decimal
    # "slicer" or "moves", nil when no box is known
    attribute :footprint_source, :string
    # The number of tools that extrude: 1 when the file extrudes without selecting a tool, nil when nothing extrudes
    attribute :tool_count, :integer
    # Tool selections (Tn) that change the tool, the first one excluded
    attribute :tool_changes, :integer
    # One { "line" => 1234, "z" => 5.4, "layer" => 27 } per M600, in file order. z and layer may be nil
    attribute :filament_changes, default: -> { [] }
    # Gcode::Summary::Tool, by tool number
    attribute :tools, default: -> { [] }

    #: (untyped io) -> Summary
    def self.read(io) = Reader.new(io).summary

    # Reads an Active Storage attachment. Raises ActiveStorage::FileNotFoundError when its file is gone from storage
    #: (untyped file) -> Summary
    def self.read_file(file) = file.blob.open { |io| read(io) }

    # Read from a file: saved as a Library::GcodeSummary, not on its own
    # @override
    #: -> bool
    def readonly? = true
  end
end
