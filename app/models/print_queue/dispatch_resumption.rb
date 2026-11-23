# typed: true
# frozen_string_literal: true

module PrintQueue
  # Resumes dispatch after PrintQueue::DispatchPause. Resuming while not paused changes nothing, but still asks for a
  # dispatch pass. See PrintQueue::Operation.
  #
  #   PrintQueue::DispatchResumption.new.save
  class DispatchResumption < Operation
    private

    # @override
    #: -> void
    def change
      setting.update!(dispatch_paused: false)
    end

    #: -> bool
    def dispatches? = true
  end
end
