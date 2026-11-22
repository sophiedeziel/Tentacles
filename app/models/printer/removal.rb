# typed: strict
# frozen_string_literal: true

class Printer
  # Removes a printer from Tentacles: its row, its jobs (queued, under way and finished) and its dashboard widgets.
  # Its files stay in the library.
  #
  #   removal = Printer::Removal.new(printer:)
  #   removal.save  # false, with errors[:base], when the printer changed while removing it (nothing was removed)
  #   removal.save! # raises instead (Printer::Removal::Conflict)
  #
  # The printer itself is never contacted: a print under way keeps running, Tentacles only stops following it. The
  # spooler drops the printer's spool without sending it anything (see Spooler#remove_printer).
  class Removal < ApplicationModel
    # The printer changed while removing it: nothing was removed
    class Conflict < StandardError; end

    # A concurrent change (e.g. a dashboard saved with a widget of this printer)
    CONFLICTS = [ActiveRecord::InvalidForeignKey, ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout,
                 ActiveRecord::RecordNotDestroyed].freeze

    attribute :printer

    validates :printer, presence: true

    rescue_into_errors Conflict

    private

    # Once the printer is destroyed, the cleanup and the pushes are best effort: a failure is logged and the next
    # steps still run.
    sig { void }
    def persist
      destroy_printer
      forget_redis_keys
      stop_spool
      push_print_queue_changed
      push_dashboard_changed
    end

    # Nothing changed when it raises
    sig { void }
    def destroy_printer
      printer.destroy!
    rescue *CONFLICTS
      raise Conflict, 'The printer changed while removing it, try again' # the ActiveRecord error is its #cause
    end

    # The monitor's snapshot, the cached API answers and the disconnected flag
    sig { void }
    def forget_redis_keys
      after_removal('forget its Redis keys') do
        Status.delete_by(printer_id: printer.id)
        ApiCache.delete_by(printer_id: printer.id)
        Disconnection.delete_by(printer_id: printer.id)
      end
    end

    sig { void }
    def stop_spool
      after_removal('stop its spool') { printer.notify_spooler(SpoolerCommand::RemovePrinter) }
    end

    # The jobs were deleted with the printer (dependent: :delete_all), so their queue push is sent here, once. The
    # printer can't be loaded back by the subscription, so its attributes are sent (see Subscriptions::PrintQueueChanged).
    sig { void }
    def push_print_queue_changed
      after_removal('push printQueueChanged') do
        attributes = printer.slice(:id, :name, :backend, :created_at, :updated_at, :last_seen_at)
        TentaclesSchema.subscriptions.trigger(:print_queue_changed, {}, { removed_printer: attributes })
      end
    end

    sig { void }
    def push_dashboard_changed
      after_removal('push dashboardChanged') { TentaclesSchema.subscriptions.trigger(:dashboard_changed, {}, {}) }
    end

    sig { params(step: String, block: T.proc.void).void }
    def after_removal(step, &block)
      block.call
    rescue StandardError => e
      Rails.logger.error("[Printer::Removal] Printer #{printer.id} was removed, but could not #{step}: " \
                         "#{e.class}: #{e.message}")
    end
  end
end
