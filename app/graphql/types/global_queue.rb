# frozen_string_literal: true

module Types
  # Query.globalQueue's object is empty: each field reads only what it needs, so a cheap selection
  # (globalQueue { dispatchPaused }) stays cheap
  class GlobalQueue < Base::Object
    description 'The global print queue, one field per section of the queue page'

    # The most finished prints returned
    MAX_FINISHED = 50
    # What a Print row reads: its printer, and its print job's file
    PRINT_PRELOADS = [:printer, { print_job: { item: { file_attachment: :blob } } }].freeze
    private_constant :PRINT_PRELOADS

    field :dispatch_paused, Boolean, null: false, resolver_method: :dispatch_paused?,
                                     description: 'Whether dispatch is paused for the whole fleet: no copy starts'
    field :printers_to_clear, [Types::Printer], null: false,
                                                description: 'The printers whose last print is still on the bed, ' \
                                                             'by id'
    field :available_printers, [Types::Printer], null: false,
                                                 description: 'The printers that take jobs and are free for one: ' \
                                                              'connected, idle, without an unfinished job and with ' \
                                                              'a clear bed, by id. Whether a waiting job fits them, ' \
                                                              'and whether dispatch is paused, aside.'
    field :offline_printers, [Types::Printer], null: false,
                                               description: 'The printers that take jobs but are offline (no ' \
                                                            'status, offline, connecting or in error): they take ' \
                                                            'nothing until they reconnect, by id. Printers that ' \
                                                            'do not take jobs are left out.'
    field :printing, [Types::Print], null: false,
                                     description: 'The copies handed to a printer and not ended (ENQUEUED or ' \
                                                  'ACTIVE), in the order they were handed out'
    field :waiting, [Types::PrintJob], null: false,
                                       description: 'The print jobs with copies left to start, in queue order. ' \
                                                    'Every one: the page reorders them.'
    field :finished, [Types::Print], null: false do
      description 'The copies that ended, the last one first'
      argument :first, Int, required: true, description: 'How many to return',
                            validates: { numericality: { within: 0..MAX_FINISHED } }
    end

    def dispatch_paused? = ::PrintQueue::Setting.current.dispatch_paused?
    def printers_to_clear = dataloader.with(Sources::FleetSource).load(:current).bed_to_clear
    def available_printers = dataloader.with(Sources::FleetSource).load(:current).available
    def offline_printers = dataloader.with(Sources::FleetSource).load(:current).offline

    def printing
      ::Printer::Job.copies.unfinished.in_queue_order.includes(*PRINT_PRELOADS)
    end

    def waiting = ::PrintQueue::NextJob.candidates.select { |entry| entry.waiting_count.positive? }

    def finished(first:)
      ::Printer::Job.copies.finished.last_finished_first.limit(first).includes(*PRINT_PRELOADS)
    end
  end
end
