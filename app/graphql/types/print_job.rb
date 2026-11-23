# frozen_string_literal: true

module Types
  # A ::PrintQueue::Job: an entry of the global queue. Its rules (needs, the printers that can print it, what happens
  # next) are batched for every print job of a query.
  class PrintJob < Base::Object
    description 'An entry of the global print queue: a file and a number of copies, each printed as a Print'

    field :id, ID, null: false
    field :file, Types::File, null: false
    field :copies, Integer, null: false, description: 'How many copies are asked for'
    field :position, Integer, null: false, description: 'Its place in the queue: lower goes first'
    field :held, Boolean, null: false, description: 'Held: no copy starts until it is released'
    field :same_printer, Boolean, null: false, description: 'Whether every copy prints on the same printer'
    field :all_capable, Boolean, null: false, method: :all_capable?,
                                 description: 'Whether every printer that can print it may: false when it ' \
                                              'is limited to a list of printers'
    field :bound_printer, Types::Printer, null: true,
                                          description: 'The printer a same-printer batch prints on: null until its ' \
                                                       'first copy starts, or once released to other printers'
    field :copies_left_to_start, Integer, null: false,
                                          description: 'The copies not handed to a printer yet (not done, printing ' \
                                                       'or failed)'
    field :needs, Types::PrintJobNeeds, null: false
    field :eligible_printers, [Types::Printer], null: false,
                                                description: 'The printers that can print it: allowed by its ' \
                                                             'printer list, not bound to another printer, and big ' \
                                                             'enough with the materials and tools it needs. Whether ' \
                                                             'they take jobs, are online or have its filament ' \
                                                             'loaded aside.'
    field :what_happens_next, Types::WhatHappensNext, null: true,
                                                      description: 'Null when nothing is left to happen to it: its ' \
                                                                   'copies are printing or finished'
    field :prints, [Types::Print], null: false, description: 'Its copies handed to a printer, by copy number'

    def file = dataload_association(:item)

    def bound_printer
      dataload_record(::Printer, object.bound_printer_id) if object.same_printer? && object.bound_printer_id
    end

    # Batched: one grouped query for the print jobs of a query
    def copies_left_to_start
      object.copy_counts = dataloader.with(Sources::CopyCountsSource).load(object.id)
      object.waiting_count
    end

    def needs = dataloader.with(Sources::PrintJobNeedsSource).load(object)

    def eligible_printers = dataloader.with(Sources::EligiblePrintersSource).load(object)

    # Computed once for the whole queue, whatever the number of print jobs of a query
    def what_happens_next = dataloader.with(Sources::ForecastSource).load(:current).outcome(object)

    def prints = dataload_association(:printer_jobs).sort_by { |print| [print.copy_number.to_i, print.id] }
  end
end
