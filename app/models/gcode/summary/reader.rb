# typed: true
# frozen_string_literal: true

module Gcode
  class Summary
    # Goes through a G-code file once, line by line, and builds its Gcode::Summary. The commands go to
    # Gcode::Summary::Moves, the comments to Gcode::Summary::SlicerValues; the slicer is found in the top comments
    # (Gcode::Slicer.identify), before the first command.
    #
    #   Gcode::Summary::Reader.new(io).summary # => a Gcode::Summary
    class Reader # rubocop:disable Metrics/ClassLength -- one pass over the file: the line dispatch, then the summary
      # A NUL byte in the start of the file means it isn't text (a .bgcode starts with "GCDE" and NUL bytes)
      SNIFF_BYTES = 4096
      CURA_LAYER = /\ALAYER:(-?\d+)/
      PRUSASLICER_LAYER = 'LAYER_CHANGE'
      PRUSASLICER_COLOUR_CHANGE = 'COLOR_CHANGE'
      # The largest values the columns hold (decimal(7,2), decimal(8,2), decimal(10,1), integer): a value beyond is
      # a broken file, Not known rather than a failed save
      MAX_COORDINATE = 99_999.99
      MAX_GRAMS = 999_999.99
      MAX_MILLIMETRES = 999_999_999.9
      MAX_SECONDS = (2**31) - 1
      MAX_TOOL = 255

      #: (untyped io) -> void
      def initialize(io)
        @io = io
        @line_number = 0 #: Integer
        @slicer = nil #: String?
        @slicer_version = nil #: String?
        @in_top_comments = true #: bool
        @layer = nil #: Integer?
        @moves = Moves.new #: Moves
        @values = SlicerValues.new #: SlicerValues
      end

      #: -> Summary
      def summary
        # Lines as bytes: a stray non-UTF-8 byte must not raise on a match. Values are made UTF-8 when kept
        @io.binmode if @io.respond_to?(:binmode)
        check_text
        @io.each_line { |line| read_line(line) }
        build_summary
      end

      private

      #: -> void
      def check_text
        start = @io.read(SNIFF_BYTES)
        raise Unreadable, 'Not a G-code text file (binary G-code is not supported)' if start&.include?("\0")

        @io.rewind
      end

      #: (String line) -> void
      def read_line(line)
        @line_number += 1
        semicolon = line.index(';')
        code = (semicolon ? line[0, semicolon] : line).to_s.strip
        if code.empty?
          read_comment(line[(semicolon + 1)..].to_s.strip) if semicolon
        else
          @in_top_comments = false
          read_command(code)
        end
      end

      #: (String comment) -> void
      def read_comment(comment)
        return identify_slicer(comment) if @in_top_comments && @slicer.nil?

        case @slicer
        when 'PrusaSlicer' then read_prusaslicer_comment(comment)
        when 'Cura' then read_cura_comment(comment)
        else @values.read(comment)
        end
      end

      #: (String comment) -> void
      def read_prusaslicer_comment(comment)
        if comment.start_with?(PRUSASLICER_LAYER)
          @layer = @layer.to_i + 1
        elsif comment.start_with?(PRUSASLICER_COLOUR_CHANGE)
          @moves.colour_change(line: @line_number, layer: @layer)
        else
          @values.read(comment)
        end
      end

      #: (String comment) -> void
      def read_cura_comment(comment)
        layer = CURA_LAYER.match(comment)
        return @values.read(comment) if layer.nil?

        # Cura counts from 0, and below 0 for a raft
        number = layer[1].to_i
        @layer = number >= 0 ? number + 1 : nil
      end

      # Cura writes its values above the line naming it: they are kept like any other
      #: (String comment) -> void
      def identify_slicer(comment)
        identified = Gcode::Slicer.identify(comment)
        if identified
          @slicer = identified[0]
          @slicer_version = SlicerValues.text(identified[1])
        else
          @values.read(comment)
        end
      end

      #: (String code) -> void
      def read_command(code)
        words = code.split
        command = words.shift.to_s.upcase
        letter = command[0]
        number = Integer(command[1..], 10, exception: false)
        return if number.nil?

        case letter
        when 'G' then read_g(number, words)
        when 'M' then read_m(number)
        when 'T' then @moves.select_tool(number) if number <= MAX_TOOL
        end
      end

      #: (Integer number, Array[String] words) -> void
      def read_g(number, words)
        case number
        when 0, 1, 2, 3 then read_move(words)
        when 28 then @moves.home(words.map { |word| word[0].to_s.upcase })
        when 90 then @moves.relative_positions = false
        when 91 then @moves.relative_positions = true
        when 92 then read_position(words)
        end
      end

      # G0 to G3. Arcs (G2, G3) count by their end point
      #: (Array[String] words) -> void
      def read_move(words)
        arguments = parse_arguments(words)
        @moves.move(arguments) if arguments
      end

      # G92
      #: (Array[String] words) -> void
      def read_position(words)
        arguments = parse_arguments(words)
        @moves.reset_position(arguments) if arguments
      end

      #: (Integer number) -> void
      def read_m(number)
        case number
        when 82 then @moves.relative_extrusion = false
        when 83 then @moves.relative_extrusion = true
        when 600 then @moves.filament_change(line: @line_number, layer: @layer)
        end
      end

      # { "X" => 10.0, "E" => 0.5 }, or nil when a value isn't a number (the line is skipped)
      #: (Array[String] words) -> Hash[String, Float]?
      def parse_arguments(words)
        words.each_with_object({}) do |word, arguments|
          axis = word[0].to_s.upcase
          next unless Moves::AXES.include?(axis)

          # A word is never empty (String#split), so word[1..] is a string
          value = Float(word[1..].to_s, exception: false) #: Float?
          return nil if value.nil? || !value.finite?

          arguments[axis] = value
        end
      end

      #: -> Summary
      def build_summary
        @moves.finish
        values = @values.for(@slicer)
        box = within_columns(values[:box]) || within_columns(@moves.box)
        Summary.new(
          slicer: @slicer, slicer_version: @slicer_version, print_seconds: at_most(values[:print_seconds], MAX_SECONDS),
          **box_attributes(box), footprint_source: box && (values[:box] ? 'slicer' : 'moves'),
          tool_count: @moves.tool_count, tool_changes: @moves.tool_count && @moves.tool_changes,
          filament_changes: @moves.filament_changes, tools: build_tools(values)
        )
      end

      # The box, or nil when a side is beyond what the columns hold. A height beyond is Not known on its own
      #: (
      #|   Hash[Symbol, Float?]? box
      #| ) -> Hash[Symbol, Float?]?
      def within_columns(box)
        return if box.nil?
        return if box.values_at(:min_x, :max_x, :min_y, :max_y).any? { |value| value.to_f.abs > MAX_COORDINATE }

        box.merge(max_z: at_most(box[:max_z], MAX_COORDINATE))
      end

      # The value, nil when beyond max (either way)
      #: (untyped value, Numeric max) -> untyped
      def at_most(value, max) = value && value.abs <= max ? value : nil

      # Numeric, not Float: Sorbet types Float#round(2) as an Integer or a Float
      #: (Hash[Symbol, Float?]? box) -> Hash[Symbol, Numeric?]
      def box_attributes(box)
        return {} if box.nil?

        attributes = box.transform_values { |value| value&.round(2) }
        attributes[:max_z] ||= at_most(@moves.max_z, MAX_COORDINATE)&.round(2)
        attributes
      end

      # A tool is listed when it extrudes, or when the slicer says it uses filament. The slicer's lists hold one value
      # per tool of the printer profile, used or not.
      #: (Hash[Symbol, untyped] values) -> Array[Tool]
      def build_tools(values)
        used = values[:millimetres].each_index.select { |tool| values[:millimetres][tool].to_f.positive? }
        (@moves.extruding_tools | used).sort.map { |tool| build_tool(tool, values) }
      end

      #: (Integer tool, Hash[Symbol, untyped] values) -> Tool
      def build_tool(tool, values)
        material_raw = values[:materials][tool]
        material = Filament.material_key(material_raw)
        Tool.new(
          tool:, material_raw:, material: Filament::MATERIALS.include?(material) ? material : nil,
          colour_hex: values[:colours][tool], **quantities(tool, values)
        )
      end

      #: (Integer tool, Hash[Symbol, untyped] values) -> Hash[Symbol, untyped]
      def quantities(tool, values)
        grams = values[:grams][tool]
        # No filament density in the profile: PrusaSlicer writes 0 g
        { millimetres: at_most(values[:millimetres][tool], MAX_MILLIMETRES)&.round(1),
          grams: grams&.positive? ? at_most(grams, MAX_GRAMS)&.round(2) : nil }
      end
    end
  end
end
