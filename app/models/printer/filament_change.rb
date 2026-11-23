# typed: strict
# frozen_string_literal: true

class Printer
  # Sets the filament loaded in a slot of a printer, for setLoadedFilament. Replaces the slot's filament, never merges:
  # the material and the colour are always given together.
  #
  #   change = Printer::FilamentChange.new(printer:, material: 'PLA', colour: 'Galaxy Black') # slot: 1
  #   change.save            # false when the filament is refused: see change.errors
  #   change.loaded_filament # the slot's saved Printer::LoadedFilament
  #
  # The errors are the loaded filament's, under the same attributes (`material`, `colour`, `slot`), so the caller can
  # tell which field they concern. Once saved, printerStatusChanged is pushed (best effort, see
  # Printer#push_status_changed). While the global queue is on, its pages are told too (PrintQueue.push_changed: an
  # entry may now fit the printer, or no longer), then a dispatch pass is asked for (PrintQueue::DispatchRequest, best
  # effort). This is the single entry point of a filament change.
  class FilamentChange < ApplicationModel
    attribute :printer
    attribute :slot, :integer, default: 1
    attribute :material, :string
    attribute :colour, :string

    validates :printer, presence: true
    validate :loaded_filament_must_be_valid

    # The slot's filament with the new values: built by the validation, saved by #save. nil until validated.
    #: LoadedFilament?
    attr_reader :loaded_filament

    # The merged errors are named like the loaded filament's attributes
    #: ((String | Symbol) attribute, ?Hash[Symbol, untyped] options) -> String
    def self.human_attribute_name(attribute, options = {})
      LoadedFilament.human_attribute_name(attribute, options)
    end

    private

    #: -> void
    def persist
      save_loaded_filament
      printer.loaded_filaments.reset # Read again by the push's subscribers
      printer.push_status_changed
      push_queue_changed
    end

    # Best effort, like the pushes and the request themselves
    #: -> void
    def push_queue_changed
      return unless PrintQueue.enabled?

      PrintQueue.push_changed([printer])
      PrintQueue::DispatchRequest.new.save
    end

    # Replaces the slot's row, or creates it. Its validations, with their error messages ("Colour can't be blank")
    #: -> void
    def loaded_filament_must_be_valid
      return unless printer

      # By printer_id: built with `printer:`, an unsaved row would join printer.loaded_filaments (has_many_inversing)
      filament = LoadedFilament.find_or_initialize_by(printer_id: printer.id, slot:)
      filament.assign_attributes(material:, colour:)
      @loaded_filament = filament #: LoadedFilament?
      errors.merge!(filament.errors) unless filament.valid?
    end

    # Two people saving at once: the unique (printer_id, slot) index decides, and the row that won is updated
    #: -> void
    def save_loaded_filament
      T.must(loaded_filament).save!
    rescue ActiveRecord::RecordNotUnique
      filament = LoadedFilament.find_by!(printer_id: printer.id, slot:)
      filament.update!(material:, colour:)
      @loaded_filament = filament
    end
  end
end
