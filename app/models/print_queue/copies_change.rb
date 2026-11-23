# typed: true
# frozen_string_literal: true

module PrintQueue
  # Changes the number of copies an entry asks for. Never below the copies done or printing (a failed copy can be
  # given up). See PrintQueue::Operation.
  #
  #   change = PrintQueue::CopiesChange.new(job:, copies: 2)
  #   change.save          # => false
  #   change.errors[:base] # => ["Can't go below 3: 2 done and 1 printing"]
  #
  # Raising the copies of a finished entry prints it again (a Requeue, e.g. to print a failed copy again): it goes back
  # into the queue, at the bottom. Raising the copies asks for a dispatch pass; lowering them doesn't.
  class CopiesChange < EntryOperation
    attribute :copies, :integer

    validates :copies, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal
      floor = job.done_count + job.printing_count
      return if copies.to_i >= floor

      counts = { 'done' => job.done_count, 'printing' => job.printing_count }.select { |_, count| count.positive? }
      "Can't go below #{floor}: #{counts.map { |name, count| "#{count} #{name}" }.join(' and ')}"
    end

    # @override
    #: -> void
    def change
      @raised = copies.to_i > job.copies
      finished = !job.unfinished?
      job.copies = copies
      requeue_at_bottom if finished
      job.save!
    end

    # A finished entry with copies waiting again goes back into the queue, at the bottom
    #: -> void
    def requeue_at_bottom
      job.position = next_position if job.unfinished?
    end

    #: -> bool
    def dispatches? = @raised == true
  end
end
