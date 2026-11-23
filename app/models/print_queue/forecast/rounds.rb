# typed: true
# frozen_string_literal: true

module PrintQueue
  class Forecast
    # The takes PrintQueue::Forecast simulates, in rounds: in each round, each printer (in serving order) takes a copy
    # of the first entry, in queue order, that has a copy left and that it's ready to take; an unbound same-printer
    # batch is bound to the first printer that takes it, and only that printer takes its other copies. The rounds go
    # on until no printer takes a copy. Read-only and computed from its inputs.
    #
    #   rounds = PrintQueue::Forecast::Rounds.new(entries:, printers: fleet.serving_order,
    #                                             ready: ->(printer, entry) { ... })
    #   rounds.takes # => [[mk4, entry], [mini, other], [mk4, entry], ...]
    class Rounds < ApplicationModel
      # Array[PrintQueue::Job]: the entries, in queue order, their copy counts preset
      attribute :entries, default: -> { [] }
      # Array[Printer]: the printers that take copies, in the order they're served
      attribute :printers, default: -> { [] }
      # Proc(Printer, PrintQueue::Job) -> bool: whether the printer would take a copy of the entry (eligible and
      # :ready), bindings aside
      attribute :ready

      # Every take, in order: [printer, entry]
      #: -> Array[[Printer, PrintQueue::Job]]
      def takes
        @takes ||= begin
          takes = [] #: Array[[Printer, PrintQueue::Job]]
          until (round = printers.filter_map { |printer| take(printer)&.then { |entry| [printer, entry] } }).empty?
            takes.concat(round)
          end
          takes
        end
      end

      # @override
      #: -> bool
      def readonly? = true

      private

      # The entry the printer takes a copy of, if any, counted as taken: one copy fewer left, and an unbound
      # same-printer batch bound to the printer
      #: (Printer printer) -> PrintQueue::Job?
      def take(printer)
        entries.find { |entry| takes?(printer, entry) }&.tap { |entry| count_taken(printer, entry) }
      end

      #: (Printer printer, PrintQueue::Job entry) -> void
      def count_taken(printer, entry)
        left[entry.id] = left.fetch(entry.id) - 1
        bound[entry.id] ||= printer.id if entry.same_printer?
      end

      # A copy left, ready to take it, and not a same-printer batch bound to another printer (so far)
      #: (Printer printer, PrintQueue::Job entry) -> bool
      def takes?(printer, entry)
        return false unless left.fetch(entry.id).positive?

        bound_to = bound[entry.id]
        return false if entry.same_printer? && bound_to && bound_to != printer.id

        ready.call(printer, entry)
      end

      # The copies left of each entry, by id
      #: -> Hash[Integer, Integer]
      def left
        @left ||= entries.to_h { |entry| [entry.id, entry.waiting_count] }
      end

      # The printer each entry is bound to, by id
      #: -> Hash[Integer, Integer?]
      def bound
        @bound ||= entries.to_h { |entry| [entry.id, entry.bound_printer_id] }
      end
    end
  end
end
