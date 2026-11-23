# typed: true
# frozen_string_literal: true

module Sources
  # The needs of the print jobs of a query: their files and G-code summaries are preloaded in one query per
  # association (none when they already are, as in globalQueue.waiting).
  #
  #   dataloader.with(Sources::PrintJobNeedsSource).load(print_job) # => PrintQueue::Needs
  class PrintJobNeedsSource < GraphQL::Dataloader::Source
    #: (Array[::PrintQueue::Job] print_jobs) -> Array[::PrintQueue::Needs]
    def fetch(print_jobs)
      ActiveRecord::Associations::Preloader.new(
        records: print_jobs, associations: { item: [{ gcode_summary: :tools }, { file_attachment: :blob }] }
      ).call
      print_jobs.map(&:needs)
    end
  end
end
