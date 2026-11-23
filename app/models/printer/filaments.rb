# typed: true
# frozen_string_literal: true

class Printer
  # The filament loaded in each of the printer's `filament_slots` (one until multi-filament, phase 9). A slot without
  # a Printer::LoadedFilament has no filament set. Changed through Printer::FilamentChange and
  # Printer::FilamentRemoval.
  module Filaments
    extend ActiveSupport::Concern

    included do
      #: self as singleton(Printer)

      # delete_all: a single DELETE, nothing to push (the database cascades too)
      has_many :loaded_filaments, class_name: 'Printer::LoadedFilament', inverse_of: :printer, dependent: :delete_all

      validates :filament_slots, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    end

    # Whether a filament is loaded in any slot (none until someone sets it)
    #: -> bool
    def filament_set? = T.bind(self, Printer).loaded_filaments.any?
  end
end
