# typed: true
# frozen_string_literal: true

class Printer
  class Status < ApplicationModel
    # Whether the printer's state changed since the snapshot was found or last saved, like ActiveModel::Dirty#changed?
    # but once rounded: jitter in the temperatures, progress or time left doesn't count, nor do the timestamps. The
    # monitor saves (and pushes) a snapshot only when it changed.
    #
    #   status = Printer::Status.find_or_initialize_by(printer:) # changed? => true for a new one, false for a found one
    #   status.reload                                           # reads the printer
    #   status.save! if status.changed?                         # save! marks the changes as applied
    module ChangeTracking
      extend ActiveSupport::Concern
      extend T::Sig

      # The values that matter for change detection: temperatures rounded to 1°, progress to 1 % and time left to
      # 1 minute. Timestamps are left out, so a snapshot only counts as changed when the printer's state did.
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def comparable_attributes
        status = T.cast(self, Printer::Status)
        {
          state_family: status.state_family, state_text: status.state_text, error_text: status.error_text,
          file_name: status.file_name,
          progress: status.progress&.round,
          print_time_left: status.print_time_left&.then { |seconds| (seconds / 60.0).round },
          hotend: status.hotend&.rounded,
          bed: status.bed&.rounded,
          camera: status.camera
        }
      end

      # True for a new snapshot
      sig { returns(T::Boolean) }
      def changed?
        saved = @saved_attributes
        saved.nil? || comparable_attributes != saved
      end

      # Marks the current state as the saved one (#changed? compares to it), like ActiveModel::Dirty#changes_applied.
      # Done by #save! and by the finders.
      sig { void }
      def changes_applied
        @saved_attributes = T.let(comparable_attributes, T.nilable(T::Hash[Symbol, T.untyped]))
      end
    end
  end
end
