# typed: true
# frozen_string_literal: true

module PrintQueue
  # Moves an entry of the queue to the top, to the bottom or to a position (1 is the first) among the entries still in
  # the queue, or right before another entry still in the queue, then numbers those entries 1..n in their new order. A
  # position past the last one is the bottom. See PrintQueue::Operation.
  #
  #   PrintQueue::Move.new(job:, to: 'top').save
  #   PrintQueue::Move.new(job:, to: 3).save
  #   PrintQueue::Move.new(job:, before: other_job).save # a drag and drop: the row it now sits above
  #
  # A position counts every entry still in the queue, those whose copies are all printing included, while the queue
  # page's Waiting list only shows the entries with copies waiting: `before` places it among the rows the page shows.
  #
  # Finished entries keep their position: they're out of the queue. Asks for a dispatch pass: a new first entry may fit
  # an idle printer.
  class Move < EntryOperation
    PLACES = %w[top bottom].freeze #: Array[String]

    # 'top', 'bottom' (Strings or Symbols), or a position: an Integer from 1. Nil when `before` is given
    attribute :to
    # The entry (a PrintQueue::Job still in the queue) it goes right before, instead of `to`
    attribute :before

    validate :place_known
    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal
      no_longer_queued || ("#{before.item.filename} is no longer in the queue" if before && !before.unfinished?)
    end

    # The entry it goes before too
    #: -> void
    def reload_records
      super
      before&.reload
    end

    # @override
    #: -> void
    def change
      others = PrintQueue::Job.unfinished.in_queue_order.where.not(id: job.id).to_a
      renumber(others.insert(index_among(others), job))
    end

    #: -> bool
    def dispatches? = true

    # Where it goes among the other entries, in queue order
    #: (Array[PrintQueue::Job] others) -> Integer
    def index_among(others)
      return others.index { |entry| entry.id == before.id } || others.size if before

      case (target = place)
      when 'top' then 0
      when 'bottom' then others.size
      else [T.cast(target, Integer) - 1, others.size].min
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
      return before_known if before

      errors.add(:to, 'must be top, bottom or a position from 1') if place.nil?
    end

    #: -> void
    def before_known
      if !to.nil?
        errors.add(:base, 'Give a place or an entry to go before, not both')
      elsif before.id == job&.id
        errors.add(:before, "can't be the entry moved")
      end
    end
  end
end
