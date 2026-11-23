# typed: true
# frozen_string_literal: true

module Sources
  # The unfinished entries of the global queue, read once per query (whatever key), in queue order with their copy
  # counts preset (PrintQueue::NextJob.candidates): globalQueue's waiting, What Happens Next, a printer's Up Next and
  # Skipped, the queue position of a print job and the demand for a loaded filament share them.
  #
  #   dataloader.with(Sources::CandidatesSource).load(:current) # => [PrintQueue::Job]
  class CandidatesSource < GraphQL::Dataloader::Source
    #: (Array[Symbol] keys) -> Array[Array[::PrintQueue::Job]]
    def fetch(keys)
      entries = ::PrintQueue::NextJob.candidates
      keys.map { entries }
    end
  end
end
