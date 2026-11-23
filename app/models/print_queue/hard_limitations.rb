# typed: true
# frozen_string_literal: true

module PrintQueue
  # Why a printer can never print an entry, whatever is loaded and whether it's online: its bed is too small, it's
  # too short, it has too few tools, or it doesn't print a material the file uses. Read from the entry's
  # PrintQueue::Needs and the printer's specs (Printer::Specs), without a query.
  #
  # A limitation needs both sides: a value the file doesn't state is never a hard limitation, and neither is a spec
  # the printer doesn't have (nil, or no materials listed).
  #
  #   limitations = PrintQueue::HardLimitations.new(needs:, printer:)
  #   limitations.any?    # => true
  #   limitations.reasons # => [PrintQueue::Reason(code: :bed_too_small,
  #                       #      message: "Bed too small: needs 230 × 210 mm, has 180 × 180 mm")]
  #
  # Codes: :bed_too_small, :too_tall, :too_few_tools, :material_not_printed.
  class HardLimitations < ApplicationModel
    attribute :needs
    attribute :printer

    # One reason per limitation, in the order above: empty when the printer can print the entry
    #: -> Array[PrintQueue::Reason]
    def reasons
      @reasons ||= [bed_size, height, tool_count, materials].compact
    end

    delegate :any?, :none?, to: :reasons

    # @override
    #: -> bool
    def readonly? = true

    private

    # The footprint's sides against the bed: X and Y for a rectangular bed (or no shape set); for a round bed, each
    # side against the diameter. Lenient on a round bed: only when certainly too big (a box whose sides fit can still
    # have corners outside the circle, but the print may not fill its corners). Sizes only, not positions: a file
    # whose box sits elsewhere on the bed (a purge line at Y -4) isn't refused for that.
    #: -> PrintQueue::Reason?
    def bed_size
      width = needs.width
      depth = needs.depth
      return if width.nil? || depth.nil?

      printer.bed_shape == 'circular' ? round_bed_size(width, depth) : rectangular_bed_size(width, depth)
    end

    #: (BigDecimal width, BigDecimal depth) -> PrintQueue::Reason?
    def rectangular_bed_size(width, depth)
      bed_x = printer.build_volume_x
      bed_y = printer.build_volume_y
      return unless too_big?(width, bed_x) || too_big?(depth, bed_y)

      reason(:bed_too_small, "Bed too small: needs #{mm(width)} × #{mm(depth)} mm, has #{mm(bed_x)} × #{mm(bed_y)} mm")
    end

    #: (BigDecimal width, BigDecimal depth) -> PrintQueue::Reason?
    def round_bed_size(width, depth)
      diameter = printer.build_diameter
      return unless too_big?(width, diameter) || too_big?(depth, diameter)

      reason(:bed_too_small, "Bed too small: needs #{mm(width)} × #{mm(depth)} mm, has a #{mm(diameter)} mm round bed")
    end

    #: -> PrintQueue::Reason?
    def height
      needed = needs.height
      available = printer.build_volume_z
      return unless too_big?(needed, available)

      reason(:too_tall, "Too tall: needs #{mm(needed)} mm of height, has #{mm(available)} mm")
    end

    #: -> PrintQueue::Reason?
    def tool_count
      needed = needs.tool_count
      available = printer.extruders
      return unless too_big?(needed, available)

      reason(:too_few_tools, "Needs #{needed} tools, has #{available}")
    end

    # The known materials the printer's list leaves out, when it lists some. A printer saved before the column had its
    # [] default reads nil: no list.
    #: -> PrintQueue::Reason?
    def materials
      listed = Array(printer.materials)
      printed = listed.map { |material| Filament.material_key(material) }
      return if printed.empty?

      missing = needs.tools.filter_map(&:material).uniq - printed
      return if missing.empty?

      reason(:material_not_printed, "Doesn't print #{missing.join(', ')} (prints #{listed.join(', ')})")
    end

    # Whether a needed value is larger than what the printer has, both known
    #: (Numeric? needed, Numeric? available) -> bool
    def too_big?(needed, available)
      !needed.nil? && !available.nil? && needed > available
    end

    #: (Numeric? value) -> String
    def mm(value)
      return '?' if value.nil?

      ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2, strip_insignificant_zeros: true)
    end

    #: (Symbol code, String message) -> PrintQueue::Reason
    def reason(code, message) = PrintQueue::Reason.new(code:, message:)
  end
end
