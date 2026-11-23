# typed: true
# frozen_string_literal: true

module Sources
  # Each print job's place among those with copies left to start (globalQueue.waiting), from 1, read once per query
  # from its candidates. nil for a print job with none left to start.
  #
  #   dataloader.with(Sources::WaitingPositionsSource).load(print_job.id) # => 3
  class WaitingPositionsSource < GraphQL::Dataloader::Source
    #: (Array[Integer] print_job_ids) -> Array[Integer?]
    def fetch(print_job_ids)
      waiting = dataloader.with(CandidatesSource).load(:current).select { |entry| entry.waiting_count.positive? }
      positions = waiting.each.with_index(1).to_h { |entry, position| [entry.id, position] }
      print_job_ids.map { |id| positions[id] }
    end
  end
end
