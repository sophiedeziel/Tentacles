# typed: true
# frozen_string_literal: true

module Library
  # What a G-code file needs to print, as read by Gcode::Summary: the time, the filament per tool (Tool rows), the
  # footprint, the tool changes and the M600 filament changes. Stored so the queue reads it without opening the file.
  #
  #   summary = item.gcode_summary
  #   summary.ready?          # => true once the file was read
  #   summary.print_seconds   # => 3725, or nil when Not known
  #   summary.filament_grams  # => 12.4: the sum over the tools, nil when any tool's grams are Not known
  #
  # Every value is nullable: nil means Not known. A re-analysis replaces the values, so whatever must keep them (the
  # queue's jobs) copies them.
  class GcodeSummary < ApplicationRecord
    belongs_to :item, class_name: 'Library::Item', foreign_key: :file_record_id, inverse_of: :gcode_summary
    has_many :tools, -> { order(:tool) }, class_name: 'Library::GcodeSummary::Tool', inverse_of: :gcode_summary,
                                          dependent: :delete_all

    enum :status, { pending: 'pending', ready: 'ready', failed: 'failed' }, validate: true
    enum :footprint_source, { slicer: 'slicer', moves: 'moves' }, prefix: :footprint_from, validate: { allow_nil: true }

    # One { "line" => 1234, "z" => 5.4, "layer" => 27 } per M600, in file order. The column defaults to [] too, but
    # Rails doesn't read an expression default before the row is reloaded
    attribute :filament_changes, :json, default: -> { [] }

    validates :file_record_id, uniqueness: true

    # The file's summary, created (pending) when it has none
    #
    #   Library::GcodeSummary.find_or_create_for!(item) # => item.gcode_summary, never nil
    #: (Library::Item item) -> Library::GcodeSummary
    def self.find_or_create_for!(item)
      item.gcode_summary || (item.gcode_summary = create_or_find_by!(file_record_id: item.id))
    end

    # Whether this row holds values read by the current Gcode::Summary::VERSION: nothing to read again
    #: -> bool
    def current?
      ready? && analysis_version >= Gcode::Summary::VERSION
    end

    # The filament for the whole print, in grams: nil when there's no tool or any tool's grams are Not known
    #: -> BigDecimal?
    def filament_grams = total(:grams)

    # The filament for the whole print, in mm: nil when there's no tool or any tool's length is Not known
    #: -> BigDecimal?
    def filament_millimetres = total(:millimetres)

    # The box, its size and where it comes from: nil when no box is known
    #: -> Footprint?
    def footprint = Footprint.of(self)

    private

    #: (Symbol attribute) -> BigDecimal?
    def total(attribute)
      values = tools.map(&attribute)
      return if values.empty? || values.any?(&:nil?)

      values.sum
    end
  end
end
