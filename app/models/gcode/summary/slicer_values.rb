# typed: true
# frozen_string_literal: true

module Gcode
  class Summary
    # The values a slicer writes in its comments: kept as written while the file is read (the first of each key), and
    # read for the slicer found once it's done. Lists are one value per tool, by position.
    #
    #   | Value             | PrusaSlicer (footer)                               | Cura (header)                      |
    #   |-------------------|----------------------------------------------------|------------------------------------|
    #   | Time              | ; estimated printing time (normal mode) = 1h 2m 3s | ;TIME:3725                         |
    #   | Length per tool   | ; filament used [mm] = 882.32, 0.00                | ;Filament used: 4.15m, 0m          |
    #   | Grams per tool    | ; filament used [g] = 2.63, 0.00                   | Not written                        |
    #   | Material per tool | ; filament_type = PLA;PETG                         | Not written                        |
    #   | Colour per tool   | ; filament_colour = #FF8000;#DDDDDD                | Not written                        |
    #   | Box               | Not written (Gcode::Summary::Moves)                | ;MINX: ;MAXX: ;MINY: ;MAXY: ;MAXZ: |
    #
    # Checked against files from PrusaSlicer 2.7.4, 2.9.2 and 2.9.6, and Cura 4.11.0.
    #
    #   values = Gcode::Summary::SlicerValues.new
    #   values.read('TIME:3725')
    #   values.for('Cura')[:print_seconds] # => 3725
    class SlicerValues
      PRUSASLICER_KEYS = [
        'filament used [mm]', 'filament used [g]', 'estimated printing time (normal mode)',
        'filament_type', 'filament_colour'
      ].freeze
      PRUSASLICER_KEY = /\A(#{Regexp.union(PRUSASLICER_KEYS).source}) = (.*)\z/
      CURA_KEY = /\A(TIME|Filament used|MINX|MAXX|MINY|MAXY|MAXZ):(.*)\z/
      DURATION = /\A(?:(\d+)d\s*)?(?:(\d+)h\s*)?(?:(\d+)m\s*)?(?:(\d+)s)?\z/
      # Seconds in each of DURATION's captures: days, hours, minutes and seconds
      DURATION_UNITS = [86_400, 3_600, 60, 1].freeze #: Array[Integer]
      HEX_COLOUR = /\A#(?:\h{3}|\h{6}|\h{8})\z/
      NOTHING = {
        print_seconds: nil, box: nil, millimetres: [], grams: [], materials: [], colours: []
      }.freeze #: Hash[Symbol, untyped]

      # A value as UTF-8 text, trimmed and cut to the 255 characters a string column holds: nil when blank
      #: (String? value) -> String?
      def self.text(value)
        return if value.nil?

        value.dup.force_encoding(Encoding::UTF_8).scrub.strip[0, 255].presence
      end

      #: -> void
      def initialize
        @values = {} #: Hash[String, String]
      end

      # One comment, without its ";"
      #: (String comment) -> void
      def read(comment)
        match = PRUSASLICER_KEY.match(comment) || CURA_KEY.match(comment)
        @values[T.must(match[1])] ||= T.must(match[2]) if match
      end

      # { print_seconds:, box:, millimetres: [], grams: [], materials: [], colours: [] } for this slicer: nil and
      # empty lists for a slicer whose comments aren't read
      #: (String? slicer) -> Hash[Symbol, untyped]
      def for(slicer)
        case slicer
        when 'PrusaSlicer' then prusaslicer
        when 'Cura' then cura
        else NOTHING
        end
      end

      private

      #: -> Hash[Symbol, untyped]
      def prusaslicer
        NOTHING.merge(
          print_seconds: duration(@values['estimated printing time (normal mode)']),
          millimetres: amounts(@values['filament used [mm]']),
          grams: amounts(@values['filament used [g]']),
          materials: list(@values['filament_type'], ';'),
          colours: list(@values['filament_colour'], ';').map { |colour| hex_colour(colour) }
        )
      end

      #: -> Hash[Symbol, untyped]
      def cura
        NOTHING.merge(
          print_seconds: amount(@values['TIME'])&.round,
          millimetres: list(@values['Filament used'], ',').map { |metres| amount(metres&.delete_suffix('m'))&.*(1000) },
          box: cura_box
        )
      end

      # The four sides are needed; MAXZ may be missing (the box's height then comes from the moves)
      #: -> Hash[Symbol, Float?]?
      def cura_box
        box = { min_x: 'MINX', max_x: 'MAXX', min_y: 'MINY', max_y: 'MAXY', max_z: 'MAXZ' }
              .transform_values { |key| number(@values[key]) }
        box unless box.values_at(:min_x, :max_x, :min_y, :max_y).any?(&:nil?)
      end

      # "1d 2h 3m 4s", "45m 10s", "30s": in seconds
      #: (String? value) -> Integer?
      def duration(value)
        captures = DURATION.match(value.to_s.strip)&.captures
        return if captures.nil? || captures.all?(&:nil?)

        captures.zip(DURATION_UNITS).sum { |count, unit| count.to_i * T.must(unit) }
      end

      #: (String? value) -> Array[Float?]
      def amounts(value) = list(value, ',').map { |item| amount(item) }

      # A coordinate: negative on a bed whose origin is its centre
      #: (String? value) -> Float?
      def number(value)
        # Annotated: Sorbet types Float() as never nil, even with exception: false
        number = Float(value.to_s.strip, exception: false) #: Float?
        number if number&.finite?
      end

      # A time or a quantity of filament
      #: (String? value) -> Float?
      def amount(value)
        number(value)&.then { |amount| amount.negative? ? nil : amount }
      end

      # "#FF8000", quoted or not: nil when it isn't a hex colour
      #: (String? value) -> String?
      def hex_colour(value)
        colour = value&.delete('"')
        colour if colour && HEX_COLOUR.match?(colour)
      end

      #: (String? value, String separator) -> Array[String?]
      def list(value, separator)
        return [] if value.nil?

        value.split(separator, -1).map { |item| self.class.text(item) }
      end
    end
  end
end
