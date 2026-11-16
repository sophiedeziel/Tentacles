# frozen_string_literal: true

module Types
  class AppKeyRequestState < Base::Enum
    description 'Where an OctoPrint app key request is (see requestPrinterAppKey)'

    value 'WAITING', 'Waiting for the user to approve it in OctoPrint', value: 'waiting'
    value 'ADDED', 'Approved: the printer was added with the new key', value: 'added'
    value 'DENIED', 'Denied in OctoPrint, or expired there', value: 'denied'
    value 'FAILED', 'OctoPrint could not be reached, or the printer could not be added (see error)', value: 'failed'
    value 'CANCELLED', 'Cancelled in Tentacles (cancelPrinterAppKeyRequest)', value: 'cancelled'
  end
end
