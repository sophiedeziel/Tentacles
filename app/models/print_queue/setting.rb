# typed: true
# frozen_string_literal: true

module PrintQueue
  # The queue's fleet-level settings: one row, created on its first read.
  #
  #   PrintQueue::Setting.dispatch_paused? # => false: the dispatcher starts copies on ready printers
  #   PrintQueue::Setting.lock_current     # the queue's lock, inside a transaction
  class Setting < ApplicationRecord
    self.table_name = 'print_queue_settings'

    # The id of the one row. Its primary key keeps two first reads from creating two rows.
    ID = 1

    # The settings row, created (with the defaults) when there's none yet
    #: -> PrintQueue::Setting
    def self.current
      find_by(id: ID) || create_or_find_by!(id: ID)
    end

    # The settings row, locked (SELECT ... FOR UPDATE) until the transaction ends: the queue's lock. The queue
    # operations (PrintQueue::Operation) and the dispatch passes take it first, so they run one at a time. Take it
    # before reading anything else in the transaction: under MySQL's REPEATABLE READ the snapshot starts at the first
    # plain read, so the reads that follow the lock see what the previous holder committed.
    #: -> PrintQueue::Setting
    def self.lock_current
      lock.find_by(id: ID) || create_or_find_by!(id: ID).lock!
    end

    # Whether the dispatcher is paused for the whole fleet: no copy is started, every entry waits
    #: -> bool
    def self.dispatch_paused? = current.dispatch_paused?
  end
end
