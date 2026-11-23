# typed: true
# frozen_string_literal: true

class Printer
  # Turns on or off whether a printer takes jobs from the global queue (the switch on its page, setPrinterTakesJobs).
  # The dispatcher skips a printer that doesn't (PrintQueue::Readiness's :not_taking_jobs); the copy it's printing goes
  # on. Refused while the global queue is off.
  #
  #   change = Printer::TakesJobsChange.new(printer:, takes_jobs: false)
  #   change.save          # => false, with errors[:base], when refused
  #
  # When the value changes, the printer's queue is pushed (PrintQueue.push_changed). Turned on, a dispatch pass is asked
  # for (PrintQueue::DispatchRequest): the printer may take a waiting job now. Setting the value it has changes nothing.
  class TakesJobsChange < ApplicationModel
    attribute :printer
    attribute :takes_jobs, :boolean

    validate :queue_enabled
    validates :printer, presence: true
    validates :takes_jobs, inclusion: { in: [true, false] }

    # A printer saved before a validation existed (e.g. its bed shape) can't be written until it's fixed
    rescue_into_errors ActiveRecord::RecordInvalid

    private

    #: -> void
    def persist
      printer.update!(takes_jobs:)
      return unless printer.saved_change_to_takes_jobs?

      PrintQueue.push_changed([printer])
      PrintQueue::DispatchRequest.new.save if takes_jobs
    end

    #: -> void
    def queue_enabled
      errors.add(:base, 'The global print queue is off') unless PrintQueue.enabled?
    end
  end
end
