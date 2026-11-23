# typed: true
# frozen_string_literal: true

module Sources
  # The copy counts of the print jobs of a query, in one grouped query (PrintQueue::Job.copy_counts).
  #
  #   dataloader.with(Sources::CopyCountsSource).load(print_job.id) # => { done: 2, printing: 1, failed: 0 }
  class CopyCountsSource < GraphQL::Dataloader::Source
    #: (Array[Integer] print_job_ids) -> Array[Hash[Symbol, Integer]]
    def fetch(print_job_ids)
      counts = ::PrintQueue::Job.copy_counts(print_job_ids)
      print_job_ids.map { |id| counts.fetch(id) }
    end
  end
end
