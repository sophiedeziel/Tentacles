# typed: true
# frozen_string_literal: true

module PrintQueue
  # Releases a held entry (PrintQueue::Hold): its copies can be dispatched again. Releasing an entry that isn't held
  # changes nothing. See PrintQueue::Operation.
  #
  #   PrintQueue::Release.new(job:).save
  #
  # Asks for a dispatch pass: an idle printer may fit it.
  class Release < EntryOperation
    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal = no_longer_queued

    # @override
    #: -> void
    def change
      job.update!(held: false)
    end

    #: -> bool
    def dispatches? = true
  end
end
