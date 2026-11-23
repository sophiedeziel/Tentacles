# frozen_string_literal: true

module Types
  # A ::Printer::Job that is a copy of a print job (a ::PrintQueue::Job)
  class Print < Base::Object
    description 'A copy of a print job, handed to a printer'

    field :id, ID, null: false
    field :copy_number, Integer, null: false, description: 'From 1, in the order the copies were handed out'
    field :print_job, Types::PrintJob, null: false
    field :printer, Types::Printer, null: false
    field :status, Types::PrintStatus, null: false
    field :progress, Float, null: false, description: 'In %, as last saved. Live, with time left: printer { status }'
    field :started_at, GraphQL::Types::ISO8601DateTime, null: true, description: 'Null until it starts'
    field :finished_at, GraphQL::Types::ISO8601DateTime, null: true, description: 'Null until it ends'
    field :result, Types::PrintResult, null: true, description: 'How it ended, null until it does'
    field :bed_cleared_at, GraphQL::Types::ISO8601DateTime, null: true,
                                                            description: 'When its bed was confirmed cleared, null ' \
                                                                         'while the print is on the bed (or before ' \
                                                                         'it ends)'
    field :bed_cleared_by, Types::BedClearedBy, null: true

    def print_job = dataload_association(:print_job)
    def printer = dataload_association(:printer)
    def result = (object.status unless ::Printer::Job::UNFINISHED_STATUSES.include?(object.status))
  end
end
