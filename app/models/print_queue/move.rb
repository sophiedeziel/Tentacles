# typed: true
# frozen_string_literal: true

module PrintQueue
  # Moves an entry of the queue to the top, to the bottom or to a position (1 is the first) among the entries still in
  # the queue, then numbers those entries 1..n in their new order. A position past the last one is the bottom. See
  # PrintQueue::Operation.
  #
  #   PrintQueue::Move.new(job:, to: 'top').save
  #   PrintQueue::Move.new(job:, to: 3).save
  #
  # Finished entries keep their position: they're out of the queue. Asks for a dispatch pass: a new first entry may fit
  # an idle printer.
  class Move < EntryOperation
    PLACES = %w[top bottom].freeze #: Array[String]

    # 'top', 'bottom' (Strings or Symbols), or a position: an Integer from 1
    attribute :to

    validate :place_known
    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal = no_longer_queued

    # @override
    #: -> void
    def change
      others = PrintQueue::Job.unfinished.in_queue_order.where.not(id: job.id).to_a
      entries = others.insert(index_among(others.size), job)
      entries.each.with_index(1) do |entry, position|
        entry.update!(position:) unless entry.position == position
      end
    end

    #: -> bool
    def dispatches? = true

    # Where it goes among the `count` other entries
    #: (Integer count) -> Integer
    def index_among(count)
      case (target = place)
      when 'top' then 0
      when 'bottom' then count
      else [T.cast(target, Integer) - 1, count].min
      end
    end

    # 'top', 'bottom', a position, or nil when `to` is none of them
    #: -> (String | Integer)?
    def place
      value = to.to_s
      return value if PLACES.include?(value)

      value.to_i if value.match?(/\A\d+\z/) && value.to_i.positive?
    end

    #: -> void
    def place_known
      errors.add(:to, 'must be top, bottom or a position from 1') if place.nil?
    end
  end
end
