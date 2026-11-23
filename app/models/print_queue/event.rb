# typed: true
# frozen_string_literal: true

module PrintQueue
  # Base of the print and printer events that write nothing the queue counts, so they don't take the queue's lock
  # (PrintQueue::Operation): PrintQueue::PrintProgress and PrintQueue::PrintPause (PrintQueue::CopyEvent),
  # PrintQueue::PrinterReady and PrintQueue::PrinterOffline. The events that change a copy's status are operations:
  # PrintQueue::PrintStart and PrintQueue::PrintEnd.
  #
  # The events are the out side of the queue's connector (PrintQueue::Connector): the spool and the monitor record them
  # while the global queue is on. Refused while it's off, like the operations.
  # @abstract
  class Event < ApplicationModel
    self.abstract_class = true

    validate :queue_enabled

    private

    #: -> void
    def queue_enabled
      errors.add(:base, 'The global print queue is off') unless PrintQueue.enabled?
    end
  end
end
