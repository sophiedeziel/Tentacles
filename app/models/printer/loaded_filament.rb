# typed: true
# frozen_string_literal: true

class Printer
  # The filament loaded in one slot of a printer: its material (one of Filament::MATERIALS) and its colour, as typed
  # (trimmed), with the key it is matched by in `colour_key`. `updated_at` is when the spool was last changed.
  #
  # No row for a slot means its filament is not set. Every printer has one slot until multi-filament (phase 9), but
  # the slots are validated against `printer.filament_slots` already.
  #
  # Written through Printer::FilamentChange and Printer::FilamentRemoval, which push printerStatusChanged: not
  # directly. A change asks the global queue for a dispatch pass (an entry may now fit the printer); a removal doesn't,
  # since it can't make an entry fit.
  class LoadedFilament < ApplicationRecord
    belongs_to :printer, inverse_of: :loaded_filaments

    normalizes :material, with: ->(value) { Filament.material_key(value) }
    normalizes :colour, with: lambda(&:squish)

    validates :material, inclusion: { in: Filament::MATERIALS }
    validates :colour, presence: true, length: { maximum: 40 }
    validates :slot, numericality: { only_integer: true, greater_than_or_equal_to: 1,
                                     less_than_or_equal_to: :slots_on_printer }
    validates :slot, uniqueness: { scope: :printer_id }

    # Keeps the matching key beside the colour (a writer, not a callback: see app/models/README.md)
    #: (untyped value) -> void
    def colour=(value)
      super
      self.colour_key = Filament.colour_key(colour)
    end

    # Whether a job asking for this material and colour can print with this filament. colour: nil means "Any colour".
    #
    #   loaded_filament.matches?(material: 'pla', colour: 'black ') # => true for PLA "Black"
    #: (material: untyped, ?colour: untyped) -> bool
    def matches?(material:, colour: nil)
      self.material == Filament.material_key(material) &&
        (colour.nil? || colour_key == Filament.colour_key(colour))
    end

    private

    # The slots are 1..printer.filament_slots
    #: -> Integer
    def slots_on_printer = printer&.filament_slots || 1
  end
end
