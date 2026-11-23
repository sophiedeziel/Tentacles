# typed: true
# frozen_string_literal: true

module PrintQueue
  # The global queue as one printer sees it, for its page: the entries with copies waiting that it qualifies for (Up
  # Next for This Printer), and the ones it skips, with why (Skipped by This Printer). Every entry with copies waiting
  # is in one of the two, in queue order. Read-only and computed from its inputs, like the rules it reuses: the
  # unfinished entries (PrintQueue::NextJob.candidates), the printer with its loaded_filaments, its Printer::Status
  # snapshot and the fleet's printers (to name a printer list or binding), so no query of its own.
  #
  #   lineup = PrintQueue::Lineup.new(printer:, status:, entries: PrintQueue::NextJob.candidates, printers:)
  #   lineup.up_next # => [PrintQueue::Job]
  #   lineup.skipped # => [PrintQueue::Lineup::Skip(entry:, reasons: ["Needs PETG. PLA is loaded here"])]
  #
  # Up next: PrintQueue::NextJob#eligible? for the printer, hold aside (a held entry stays up next: it's on hold until
  # released), and its filament loaded (PrintQueue::Fit#filament_loaded?: :ready, or :after_reconnect only because the
  # printer is offline). What happens next to it is PrintQueue::Forecast's, as on the queue page: the printer may not
  # be the one that takes it.
  #
  # Skipped, with every reason that applies, in this order:
  # - its G-code is still being read (no other reason is known yet)
  # - its printer list leaves this printer out: "Limited to Voron 2.4"
  # - it's a same-printer batch bound to another printer: "Same-printer batch on Prusa XL"
  # - a hard limitation (PrintQueue::HardLimitations, Fit :cannot): "Bed too small: needs ..."
  # - else, the filament to change (PrintQueue::Fit#filament_changes): "Needs PLA White. PLA Black is loaded here"
  #
  # The printer's own state (not taking jobs, offline, busy, a bed to clear) skips nothing: it delays every entry
  # alike, and its page shows it apart.
  class Lineup < ApplicationModel
    # An entry the printer skips, and why: one message per reason, never empty
    class Skip < ApplicationModel
      attribute :entry
      # Array[String]
      attribute :reasons, default: -> { [] }

      # @override
      #: -> bool
      def readonly? = true
    end

    attribute :printer
    attribute :status
    # Array[PrintQueue::Job]: the unfinished entries, their copy counts preset (PrintQueue::NextJob.candidates)
    attribute :entries, default: -> { [] }
    # Array[Printer]: the fleet, to name the printers an entry is limited or bound to
    attribute :printers, default: -> { [] }

    # The entries it qualifies for, in queue order
    #: -> Array[PrintQueue::Job]
    def up_next
      waiting.select { |entry| reasons(entry).empty? }
    end

    # The entries it skips, in queue order
    #: -> Array[PrintQueue::Lineup::Skip]
    def skipped
      waiting.filter_map do |entry|
        reasons = reasons(entry)
        Skip.new(entry:, reasons:) if reasons.any?
      end
    end

    # @override
    #: -> bool
    def readonly? = true

    private

    # The entries with copies waiting, in queue order (the queue page's Waiting)
    #: -> Array[PrintQueue::Job]
    def waiting
      @waiting ||= entries.select { |entry| entry.waiting_count.positive? }
                          .sort_by { |entry| [entry.position, entry.id] }
    end

    # Why the printer skips the entry: empty when it qualifies
    #: (PrintQueue::Job entry) -> Array[String]
    def reasons(entry)
      @reasons ||= {} #: Hash[Integer, Array[String]]?
      @reasons[entry.id] ||= begin
        needs = entry.needs
        fit = PrintQueue::Fit.new(needs:, printer:, status:)
        fit_reasons = if !needs.runnable? then ['Its G-code is still being read']
                      elsif fit.cannot? then fit.reasons.filter_map(&:message)
                      else fit.filament_changes.filter_map(&:message)
                      end
        [*closed_reasons(entry), *fit_reasons]
      end
    end

    # Its printer list and binding (PrintQueue::Job#open_to?)
    #: (PrintQueue::Job entry) -> Array[String]
    def closed_reasons(entry)
      listed = entry.all_capable? || entry.job_printers.any? { |job_printer| job_printer.printer_id == printer.id }
      [("Limited to #{names(entry.job_printers.map(&:printer_id))}" unless listed), bound_elsewhere(entry)].compact
    end

    # A same-printer batch bound to another printer
    #: (PrintQueue::Job entry) -> String?
    def bound_elsewhere(entry)
      bound_to = entry.bound_printer_id
      "Same-printer batch on #{names([bound_to])}" if entry.same_printer? && bound_to && bound_to != printer.id
    end

    # "Voron 2.4, Prusa XL": the printers with these ids, by id ("another printer" when none is left)
    #: (Array[Integer?] ids) -> String
    def names(ids)
      named = printers.select { |each| ids.include?(each.id) }.sort_by(&:id).map(&:name)
      named.any? ? named.to_sentence(two_words_connector: ', ', last_word_connector: ', ') : 'another printer'
    end
  end
end
