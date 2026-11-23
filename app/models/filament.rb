# typed: strict
# frozen_string_literal: true

# What a printer can have loaded (Printer::LoadedFilament), and the keys filaments are matched by. Outside Printer
# because the queue's jobs and the G-code analysis match filaments with the same keys.
#
#   Filament.material_key(' pla ')       # => "PLA"
#   Filament.colour_key(' Galaxy  BLACK') # => "galaxy black"
#
# Two colours match when their keys are equal: "Black" matches "black " but not "Galaxy Black".
module Filament
  extend T::Sig

  # Closed list, so that matching is reliable. Adding a material is a one-line change.
  MATERIALS = T.let(%w[PLA PETG ABS ASA TPU PC PA PVA HIPS].freeze, T::Array[String])

  # Suggested first when a colour is typed, so that the same colour is picked rather than retyped another way
  DEFAULT_COLOURS = T.let(
    %w[Black White Grey Silver Red Orange Yellow Green Blue Purple Pink Brown Transparent].freeze, T::Array[String]
  )

  # The colours to suggest: DEFAULT_COLOURS, then every loaded colour (alphabetical) whose key isn't already listed.
  # Each colour appears once, by key: "Galaxy Black" and "galaxy black" share one entry, spelled as it was last loaded.
  #
  #   Filament.colour_suggestions # => ["Black", "White", ..., "Transparent", "Galaxy Black", "Silk Gold"]
  sig { returns(T::Array[String]) }
  def self.colour_suggestions
    in_use = Printer::LoadedFilament.order(updated_at: :desc, id: :desc).pluck(:colour)
                                    .uniq { |colour| colour_key(colour) }.sort_by { |colour| colour_key(colour) }
    (DEFAULT_COLOURS + in_use).uniq { |colour| colour_key(colour) }
  end

  sig { params(value: T.untyped).returns(String) }
  def self.material_key(value) = value.to_s.strip.upcase

  # Trimmed, single-spaced and lower-cased, after Unicode NFKC normalisation
  sig { params(value: T.untyped).returns(String) }
  def self.colour_key(value) = value.to_s.unicode_normalize(:nfkc).squish.downcase
end
