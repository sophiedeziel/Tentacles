# typed: true
# frozen_string_literal: true

module Gcode
  class Summary
    # Follows the nozzle through a file's commands, keeping counters only: the box of the extruding moves, the tools
    # that extrude, the tool changes and the filament changes (M600).
    #
    # - A move extrudes when E rises (absolute extrusion, M82) or is positive (relative, M83). G92 sets the position,
    #   G90 and G91 make positions absolute or relative (relative positions make E relative too, as in Marlin), and
    #   G28 makes the homed axes unknown until the next move sets them.
    # - The box holds both ends of every extruding move along X or Y (retractions, travels and extrusion in place
    #   don't count). Arcs count by their ends.
    #
    #   moves = Gcode::Summary::Moves.new
    #   moves.move('X' => 10.0, 'Y' => 10.0)
    #   moves.move('X' => 20.0, 'E' => 1.0)
    #   moves.box # => { min_x: 10.0, max_x: 20.0, min_y: 10.0, max_y: 10.0, max_z: nil }
    class Moves # rubocop:disable Metrics/ClassLength -- one tracker of the nozzle's state, a short method per command
      AXES = %w[X Y Z E].freeze #: Array[String]
      POSITION_AXES = %w[X Y Z].freeze #: Array[String]
      # Smaller changes of E are rounding, not extrusion
      EPSILON = 0.00001

      #: Integer
      attr_reader :tool_changes

      #: Array[Hash[String, untyped]]
      attr_reader :filament_changes

      #: Array[Integer]
      attr_reader :extruding_tools

      #: Float?
      attr_reader :max_z

      #: bool
      attr_writer :relative_positions

      #: bool
      attr_writer :relative_extrusion

      #: -> void
      def initialize # rubocop:disable Metrics/MethodLength -- one typed declaration per counter
        @position = { 'X' => nil, 'Y' => nil, 'Z' => nil } #: Hash[String, Float?]
        @e = 0.0 #: Float
        @relative_positions = false #: bool
        @relative_extrusion = false #: bool
        @min_x = nil #: Float?
        @max_x = nil #: Float?
        @min_y = nil #: Float?
        @max_y = nil #: Float?
        @max_z = nil #: Float?
        @tool = nil #: Integer?
        @tool_changes = 0 #: Integer
        @extruding_tools = [] #: Array[Integer]
        @extruded_before_tool = false #: bool
        @filament_changes = [] #: Array[Hash[String, untyped]]
        @colour_change_open = false #: bool
      end

      # G0 to G3: arguments by axis ("X", "Y", "Z", "E")
      #: (Hash[String, Float] arguments) -> void
      def move(arguments)
        from_x = @position['X']
        from_y = @position['Y']
        POSITION_AXES.each { |axis| @position[axis] = target(axis, arguments[axis]) if arguments.key?(axis) }
        return unless extrudes?(arguments['E'])

        extruded
        include_move(from_x, from_y) if arguments.key?('X') || arguments.key?('Y')
      end

      # G92: the given axes now read these values, all of them 0 when none is given
      #: (Hash[String, Float] arguments) -> void
      def reset_position(arguments)
        arguments = AXES.index_with(0.0) if arguments.empty?
        arguments.each do |axis, value|
          axis == 'E' ? @e = value : @position[axis] = value
        end
      end

      # G28: the axes homed (every axis when none is named) are unknown until a move sets them
      #: (Array[String] letters) -> void
      def home(letters)
        homed = letters & POSITION_AXES
        (homed.empty? ? POSITION_AXES : homed).each { |axis| @position[axis] = nil }
      end

      # Tn. The first selection isn't a change; a selection of the current tool isn't either
      #: (Integer tool) -> void
      def select_tool(tool)
        if @tool.nil?
          # What extruded before the first selection (a prime line) was done with this tool
          @extruding_tools |= [tool] if @extruded_before_tool
        elsif tool != @tool
          @tool_changes += 1
        end
        @tool = tool
      end

      # M600
      #: (line: Integer, layer: Integer?) -> void
      def filament_change(line:, layer:)
        if @colour_change_open
          # The M600 of PrusaSlicer's ;COLOR_CHANGE: one change, at the M600's line
          T.must(@filament_changes.last)['line'] = line
          @colour_change_open = false
        else
          @filament_changes << change(line, layer)
        end
      end

      # PrusaSlicer's ;COLOR_CHANGE comment, written just before its colour change G-code (M600 by default)
      #: (line: Integer, layer: Integer?) -> void
      def colour_change(line:, layer:)
        @filament_changes << change(line, layer)
        @colour_change_open = true
      end

      # After the last line
      #: -> void
      def finish
        # Extruded without ever selecting a tool: the only tool, T0
        @extruding_tools |= [0] if @extruded_before_tool && @tool.nil?
      end

      #: -> Integer?
      def tool_count = @extruding_tools.empty? ? nil : @extruding_tools.size

      # nil when no extruding move had a known position
      #: -> Hash[Symbol, Float?]?
      def box
        return if [@min_x, @max_x, @min_y, @max_y].any?(&:nil?)

        { min_x: @min_x, max_x: @max_x, min_y: @min_y, max_y: @max_y, max_z: @max_z }
      end

      private

      #: (String axis, Float? value) -> Float?
      def target(axis, value)
        return value unless @relative_positions

        current = @position[axis]
        current && value && (current + value)
      end

      #: (Float? e_value) -> bool
      def extrudes?(e_value)
        return false if e_value.nil?

        if @relative_extrusion || @relative_positions
          # Kept up to date, for when extrusion turns absolute again without a G92
          @e += e_value
          return e_value > EPSILON
        end

        rising = e_value > @e + EPSILON
        @e = e_value
        rising
      end

      #: -> void
      def extruded
        @colour_change_open = false
        if @tool.nil?
          @extruded_before_tool = true
        else
          @extruding_tools |= [@tool]
        end
      end

      # An extruding move along X or Y: both its ends, and its height
      #: (Float? from_x, Float? from_y) -> void
      def include_move(from_x, from_y)
        include_point(from_x, from_y)
        include_point(@position['X'], @position['Y'])
        z = @position['Z']
        @max_z = z if z && (@max_z.nil? || z > @max_z)
      end

      # Not min/max of arrays, nor a method per bound: this runs twice for every extruding move
      #: (Float? point_x, Float? point_y) -> void
      def include_point(point_x, point_y) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        if point_x
          @min_x = point_x if @min_x.nil? || point_x < @min_x
          @max_x = point_x if @max_x.nil? || point_x > @max_x
        end
        return unless point_y

        @min_y = point_y if @min_y.nil? || point_y < @min_y
        @max_y = point_y if @max_y.nil? || point_y > @max_y
      end

      #: (Integer line, Integer? layer) -> Hash[String, untyped]
      def change(line, layer)
        z = @position['Z']
        { 'line' => line, 'z' => z&.round(2), 'layer' => layer }
      end
    end
  end
end
