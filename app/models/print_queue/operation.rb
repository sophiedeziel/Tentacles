# typed: true
# frozen_string_literal: true

module PrintQueue
  # Base of the global queue's operations: PrintQueue::Addition, PrintQueue::Move, PrintQueue::Hold, ...
  #
  #   hold = PrintQueue::Hold.new(job:)
  #   hold.save          # => false, with a readable message in errors[:base], when refused
  #   hold.errors[:base] # => ['cube.gcode is no longer in the queue']
  #
  # Saving one:
  # 1. validates: refused while the global queue is off, then its inputs, then its #refusal (the state of the queue
  #    doesn't allow it)
  # 2. writes its #change in one transaction, under the queue's lock (PrintQueue::Setting.lock_current: operations and
  #    dispatch passes run one at a time, so two moves can't give two entries the same position, and a copy can't be
  #    dispatched while copies are counted). It first reads its records again (#reload_records) and checks its
  #    #refusal again: the queue may have changed since it was validated. `save` then returns false with that message.
  # 3. pushes PrintQueue.push_changed(#pushed_printers), once, after the commit
  # 4. asks for a dispatch pass (PrintQueue::DispatchRequest) when it can make a printer eligible (#dispatches?)
  #
  # Subclasses implement #change, and optionally #refusal, #reload_records, #pushed_printers and #dispatches?. A
  # subclass with a #refusal declares `validate :allowed, unless: :refused?` after its own validations, so the refusal
  # is only checked on valid inputs.
  # @abstract
  class Operation < ApplicationModel
    self.abstract_class = true

    # The queue changed since the operation was validated and no longer allows it, or a step was refused
    class Refused < StandardError; end

    validate :queue_enabled

    rescue_into_errors Refused, ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout

    private

    #: -> void
    def persist
      write
      PrintQueue.push_changed(pushed_printers)
      PrintQueue::DispatchRequest.new.save if dispatches?
    end

    #: -> void
    def write
      ApplicationRecord.transaction do
        @setting = PrintQueue::Setting.lock_current
        reload_records
        message = refusal
        raise Refused, message if message

        change
      end
    end

    # The write, inside the transaction (the settings row is locked: #setting)
    # @abstract
    #: -> void
    def change = super

    # Why the operation isn't allowed in the queue's current state, nil when it is
    #: -> String?
    def refusal = nil

    # Reads again, under the queue's lock, the records the refusal and the change read
    #: -> void
    def reload_records; end

    # The printers whose queue changed (PrintQueue.push_changed)
    #: -> Array[Printer]
    def pushed_printers = []

    # Whether the change can make a printer eligible for an entry
    #: -> bool
    def dispatches? = false

    # The settings row, locked, during #change
    #: PrintQueue::Setting
    attr_reader :setting

    # After the last entry, finished entries included
    #: -> Integer
    def next_position = (PrintQueue::Job.maximum(:position) || 0) + 1

    #: -> bool
    def refused? = errors.any?

    #: -> void
    def queue_enabled
      errors.add(:base, 'The global print queue is off') unless PrintQueue.enabled?
    end

    #: -> void
    def allowed
      message = refusal
      errors.add(:base, message) if message
    end

    #: (Exception error) -> String
    def error_message_for(error)
      case error
      when ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout then 'The queue is busy, try again'
      else super
      end
    end
  end
end
