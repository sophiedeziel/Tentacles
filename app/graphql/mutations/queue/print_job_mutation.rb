# typed: true
# frozen_string_literal: true

module Mutations
  module Queue
    # Base for the mutations on one print job of the global queue (holdPrintJob, movePrintJob, ...): each finds the
    # ::PrintQueue::Job and saves a queue operation (a ::PrintQueue::EntryOperation), which checks that the queue is on
    # and allows it, writes the change and pushes it.
    #
    # Never raises for a refusal: the operation's message comes back in `errors`, with the print job as it is.
    #
    # Subclasses implement `operation_for(job, **arguments)`, and declare their own arguments.
    # @abstract
    class PrintJobMutation < Base::Mutation
      argument :id, ID, required: true, description: 'The print job'

      field :success, Boolean, null: false, description: 'Whether it was saved'
      field :errors, [Types::UserError], null: false, description: 'Why it was refused, empty when it was saved'
      field :print_job, Types::PrintJob, null: true,
                                         description: 'The print job as saved, or as it is when refused. Null ' \
                                                      'when it was not found.'

      #: (id: String, **untyped arguments) -> Hash[Symbol, untyped]
      def resolve(id:, **arguments)
        job = ::PrintQueue::Job.find_by(id:)
        return not_found if job.nil?

        result(operation_for(job, **arguments), job)
      end

      private

      # The unsaved operation, built from the subclass's own arguments
      #: (::PrintQueue::Job job, **untyped arguments) -> ::PrintQueue::Operation
      def operation_for(job, **arguments)
        raise NotImplementedError, "#{self.class.name} builds no operation"
      end

      # Saves it: the print job as saved, or read again when refused (the operation may have read it under the
      # queue's lock)
      #: (::PrintQueue::Operation operation, ::PrintQueue::Job job) -> Hash[Symbol, untyped]
      def result(operation, job)
        return { success: true, errors: [], print_job: job } if operation.save

        { success: false, errors: Types::UserError.from(operation.errors),
          print_job: ::PrintQueue::Job.find_by(id: job.id) }
      end

      #: (?String message, ?field: String?) -> Hash[Symbol, untyped]
      def not_found(message = 'Print job not found', field: nil)
        { success: false, errors: [{ field:, message: }], print_job: nil }
      end
    end
  end
end
