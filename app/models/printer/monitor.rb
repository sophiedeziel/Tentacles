# typed: strict
# frozen_string_literal: true

class Printer
  # Polls each printer's server (OctoPrint, PrusaLink) and publishes its live state as Printer::Status snapshots: the
  # process that bin/printer_monitor runs (see Supervisor and Worker).
  #
  #   Printer::Monitor::Supervisor.new.run # Blocks until INT or TERM
  #
  # A namespace only. To refresh one printer's snapshot outside of the monitor (e.g. right after a command), reload its
  # status and save it:
  #
  #   status = Printer::Status.find_or_initialize_by(printer:).reload
  #   status.save! if status.changed?
  module Monitor
  end
end
