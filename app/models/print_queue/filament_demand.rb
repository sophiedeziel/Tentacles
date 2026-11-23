# typed: true
# frozen_string_literal: true

module PrintQueue
  # How many entries with copies waiting (held ones included) ask for exactly a filament: its material for the slot's
  # tool (tool n uses slot n + 1, as in PrintQueue::Fit) and its colour. An entry asking for Any colour, or whose file
  # doesn't say the tool's material, asks for no exact filament: it isn't counted, though it may print with it. For
  # the hint under a printer's Loaded Filament ("No waiting job asks for PLA White"). Whatever printer an entry is
  # limited to: the count is the queue's.
  #
  #   demand = PrintQueue::FilamentDemand.new(entries: PrintQueue::NextJob.candidates)
  #   demand.count(material: 'PLA', colour: 'White') # => 3, for slot 1
  #   demand.count_for(loaded_filament)               # the same, for a Printer::LoadedFilament
  #
  # Read once from the entries' needs (their summaries preloaded by the candidates): no query.
  class FilamentDemand < ApplicationModel
    # Array[PrintQueue::Job]: the unfinished entries, their copy counts preset (PrintQueue::NextJob.candidates)
    attribute :entries, default: -> { [] }

    #: (material: String, colour: String, ?slot: Integer) -> Integer
    def count(material:, colour:, slot: 1)
      counts.fetch([slot, Filament.material_key(material), Filament.colour_key(colour)], 0)
    end

    #: (Printer::LoadedFilament filament) -> Integer
    def count_for(filament) = count(material: filament.material, colour: filament.colour, slot: filament.slot)

    # @override
    #: -> bool
    def readonly? = true

    private

    # How many entries ask for each [slot, material key, colour key]
    #: -> Hash[[Integer, String, String], Integer]
    def counts
      @counts ||= entries.select { |entry| entry.waiting_count.positive? && entry.colour_key }
                         .flat_map { |entry| asked(entry) }.tally
    end

    # What the entry asks for, once per slot
    #: (PrintQueue::Job entry) -> Array[[Integer, String, String]]
    def asked(entry)
      entry.needs.tools.filter_map do |tool|
        [tool.tool.to_i + 1, Filament.material_key(tool.material), entry.colour_key] if tool.material
      end.uniq
    end
  end
end
