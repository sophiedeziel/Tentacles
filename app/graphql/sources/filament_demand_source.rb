# typed: true
# frozen_string_literal: true

module Sources
  # How many waiting entries ask for each filament (PrintQueue::FilamentDemand), read once per query from its
  # candidates, whatever the number of loaded filaments.
  #
  #   dataloader.with(Sources::FilamentDemandSource).load(:current).count_for(loaded_filament) # => 3
  class FilamentDemandSource < GraphQL::Dataloader::Source
    #: (Array[Symbol] keys) -> Array[::PrintQueue::FilamentDemand]
    def fetch(keys)
      demand = ::PrintQueue::FilamentDemand.new(entries: dataloader.with(CandidatesSource).load(:current))
      keys.map { demand }
    end
  end
end
