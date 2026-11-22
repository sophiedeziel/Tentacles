# typed: true
# frozen_string_literal: true

class Printer
  # Uploads a G-code file to the printer through its API adapter, and starts printing it when `print` is true.
  #
  #   Printer::Upload.new(printer:, path: 'tmp/cube.gcode', print: true).save!
  #
  # Use #save!: errors (including timeouts) are raised to the caller, since an upload must not fail silently. Nor
  # does it mark the printer as disconnected: it doesn't go through Printer#using_api and its cache.
  class Upload < ApplicationModel
    attribute :printer
    # The local path of the file
    attribute :path, :string
    # Whether to start printing the file once uploaded
    attribute :print, :boolean, default: false

    validates :printer, :path, presence: true

    private

    sig { void }
    def persist
      printer.api.upload(path, print: self.print) # self: not Kernel#print
    end
  end
end
