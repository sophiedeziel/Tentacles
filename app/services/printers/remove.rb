# typed: strict
# frozen_string_literal: true

module Printers
  # Removes a printer from Tentacles: its row, its jobs (queued, under way and finished) and its dashboard widgets.
  # Its files stay in the library.
  #
  #   Printers::Remove.call(printer)
  #
  # The printer itself is never contacted: a print under way keeps running, Tentacles only stops following it. The
  # spooler drops the printer's spool without sending it anything (see Spooler#remove_printer).
  class Remove
    extend T::Sig

    sig { params(printer: ::Printer).void }
    def self.call(printer)
      new(printer).call
    end

    sig { params(printer: ::Printer).void }
    def initialize(printer)
      @printer = printer
    end

    # Raises when the printer can't be destroyed (nothing changed then). Once it's destroyed, the cleanup and the
    # pushes are best effort: a failure is logged and the next steps still run.
    sig { void }
    def call
      @printer.destroy!

      after_removal('forget its Redis keys') { forget }
      after_removal('stop its spool') { @printer.notify_spooler(:remove_printer) }
      after_removal('push printQueueChanged') { push_print_queue_changed }
      after_removal('push dashboardChanged') { TentaclesSchema.subscriptions.trigger(:dashboard_changed, {}, {}) }
    end

    private

    # The monitor's snapshot, the cached API answers and the disconnected flag
    sig { void }
    def forget
      PrinterStatusStore.delete([@printer.id])
      PrinterApiCache.forget(@printer.id)
    end

    # The jobs were deleted without callbacks (dependent: :delete_all), so their queue push is sent here, once. The
    # printer can't be loaded back by the subscription, so its attributes are sent (see Subscriptions::PrintQueueChanged).
    sig { void }
    def push_print_queue_changed
      attributes = @printer.slice(:id, :name, :backend, :created_at, :updated_at, :last_seen_at)
      TentaclesSchema.subscriptions.trigger(:print_queue_changed, {}, { removed_printer: attributes })
    end

    sig { params(step: String, block: T.proc.void).void }
    def after_removal(step, &block)
      block.call
    rescue StandardError => e
      Rails.logger.error("[Printers::Remove] Printer #{@printer.id} was removed, but could not #{step}: " \
                         "#{e.class}: #{e.message}")
    end
  end
end
