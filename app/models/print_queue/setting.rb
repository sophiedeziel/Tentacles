# typed: true
# frozen_string_literal: true

module PrintQueue
  # The queue's fleet-level settings: one row, created on its first read.
  #
  #   PrintQueue::Setting.dispatch_paused? # => false: the dispatcher starts copies on ready printers
  #   PrintQueue::Setting.current.lock!    # serializes dispatch passes (phase 3's dispatcher)
  class Setting < ApplicationRecord
    self.table_name = 'print_queue_settings'

    # The id of the one row. Its primary key keeps two first reads from creating two rows.
    ID = 1

    # The settings row, created (with the defaults) when there's none yet
    #: -> PrintQueue::Setting
    def self.current
      find_by(id: ID) || create_or_find_by!(id: ID)
    end

    # Whether the dispatcher is paused for the whole fleet: no copy is started, every entry waits
    #: -> bool
    def self.dispatch_paused? = current.dispatch_paused?
  end
end
