# typed: strict
# frozen_string_literal: true

class Printer
  # Removes the filament loaded in a slot of a printer, for clearLoadedFilament: the slot's filament is "not set"
  # again.
  #
  #   removal = Printer::FilamentRemoval.new(printer:) # slot: 1
  #   removal.save!
  #   removal.removed? # false when the slot had no filament: a success that changes nothing
  #
  # printerStatusChanged is pushed (best effort, see Printer#push_status_changed) only when a filament was removed:
  # nothing changed otherwise. While the global queue is on, its pages are told too (PrintQueue.push_changed: what
  # happens next to an entry may change). No dispatch pass is asked for: an empty slot makes no entry fit.
  class FilamentRemoval < ApplicationModel
    attribute :printer
    attribute :slot, :integer, default: 1

    validates :printer, :slot, presence: true

    # Whether #save removed a filament
    #: -> bool
    def removed?
      @removed == true
    end

    private

    #: -> void
    def persist
      @removed = printer.loaded_filaments.where(slot:).delete_all.positive? #: bool?
      return unless @removed

      printer.loaded_filaments.reset # Read again by the push's subscribers
      printer.push_status_changed
      PrintQueue.push_changed([printer]) if PrintQueue.enabled?
    end
  end
end
