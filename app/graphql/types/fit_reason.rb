# frozen_string_literal: true

module Types
  # A ::PrintQueue::Reason of a ::PrintQueue::Fit
  class FitReason < Base::Object
    description 'One reason a printer fits a print job as it does'

    field :code, Types::FitReasonCode, null: false
    field :message, String, null: false,
                            description: 'e.g. "Needs PETG. PLA is loaded here" or "Bed too small: needs 120 × 80 ' \
                                         'mm, has a 110 mm round bed". "Slot 2: " first on a printer with several ' \
                                         'slots.'
  end
end
