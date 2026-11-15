# frozen_string_literal: true

module Types
  class PrinterBackend < Base::Enum
    description 'The server Tentacles talks to for a printer'

    value 'OCTOPRINT', 'OctoPrint, with an API key', value: 'octoprint'
    value 'PRUSALINK', 'PrusaLink (Prusa MK4, XL, MINI, ... without OctoPrint), with a username and a password',
          value: 'prusalink'
  end
end
