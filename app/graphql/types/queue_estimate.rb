# frozen_string_literal: true

module Types
  # A ::PrintQueue::Estimate
  class QueueEstimate < Base::Object
    description 'The summary of the Add to Queue form (and of the Edit page): the queue now, the filament and the ' \
                'print time of its copies, and what happens to it first. Read-only: nothing is saved.'

    field :printing, Integer, null: false, method: :printing_count,
                              description: 'The copies handed to a printer and not ended, in the whole queue'
    field :waiting_jobs, Integer, null: false,
                                  description: 'The print jobs with copies left to start now (the one edited included)'
    field :jobs_ahead, Integer, null: false,
                                description: 'The print jobs with copies left to start that go before it'
    field :prints_ahead, Integer, null: false, description: 'The copies left to start of the print jobs ahead of it'
    field :copies_to_print, Integer, null: false,
                                     description: 'The copies the totals count: the copies asked for, less those ' \
                                                  'done, printing or failed when editing'
    field :filaments, [Types::EstimatedFilament], null: false,
                                                  description: 'One per tool it needs, in tool order: empty when no ' \
                                                               'tool is known'
    field :filament_grams, Float, null: true,
                                  description: "The G-code summary's filament × copiesToPrint. Null when Not known"
    field :filament_metres, Float, null: true,
                                   description: "The G-code summary's filament length × copiesToPrint. Null when " \
                                                'Not known'
    field :print_seconds, Integer, null: true,
                                   description: "The G-code summary's print time × copiesToPrint, one copy after " \
                                                'another. Null when Not known'
    field :starts, Types::WhatHappensNext, null: true,
                                           description: 'What happens to it first, as if it were in the queue (the ' \
                                                        'What Happens Next of the queue page). startsAt is null ' \
                                                        'until the queue simulation ships. Null when no copy is ' \
                                                        'left to start.'

    def filament_metres = object.filament_millimetres&./(1000)
  end
end
