# typed: true
# frozen_string_literal: true

module PrintQueue
  # Pauses dispatch for the whole fleet: no copy is dispatched until PrintQueue::DispatchResumption. Copies already
  # dispatched go on. Pausing while paused changes nothing. See PrintQueue::Operation.
  #
  #   PrintQueue::DispatchPause.new.save
  class DispatchPause < Operation
    private

    # @override
    #: -> void
    def change
      setting.update!(dispatch_paused: true)
    end
  end
end
