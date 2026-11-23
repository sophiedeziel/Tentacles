# typed: true
# frozen_string_literal: true

module PrintQueue
  # Holds an entry: it keeps its place, but no copy is dispatched until it's released (PrintQueue::Release). Copies
  # already printing go on. Holding a held entry changes nothing. See PrintQueue::Operation.
  #
  #   PrintQueue::Hold.new(job:).save
  class Hold < EntryOperation
    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal = no_longer_queued

    # @override
    #: -> void
    def change
      job.update!(held: true)
    end
  end
end
