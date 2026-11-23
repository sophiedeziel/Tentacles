# frozen_string_literal: true

module Types
  # A ::PrintQueue::Fit of the print job the Add to Queue form describes
  class PrinterFit < Base::Object
    description 'How a printer fits a print job as the Add to Queue form describes it: the rule the dispatcher uses'

    field :printer, Types::Printer, null: false
    field :result, Types::FitResult, null: false
    field :reasons, [Types::FitReason], null: false,
                                        description: 'Why: the hard limits for CANNOT; the offline state and the ' \
                                                     'filament changes for AFTER_RECONNECT; the filament changes ' \
                                                     'for AFTER_FILAMENT_CHANGE; what matched for READY. Never empty.'
    field :hard_limit, Boolean, null: false, resolver_method: :hard_limit?,
                                description: 'Whether it can never print it (CANNOT): a printer list naming it is ' \
                                             'refused. Offline and another filament loaded are never hard limits, ' \
                                             'and neither is a value that is not known.'

    def hard_limit? = object.cannot?
  end
end
