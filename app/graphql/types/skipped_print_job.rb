# frozen_string_literal: true

module Types
  # A ::PrintQueue::Lineup::Skip: a waiting print job a printer skips, and why
  class SkippedPrintJob < Base::Object
    description 'A print job with copies left to start that a printer skips, and why'

    field :print_job, Types::PrintJob, null: false
    field :reasons, [String], null: false,
                              description: 'Why, one reason each, e.g. "Limited to Voron 2.4" or "Needs PLA White. ' \
                                           'PLA Black is loaded here". Never empty.'

    def print_job = object.entry
  end
end
