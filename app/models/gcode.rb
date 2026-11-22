# frozen_string_literal: true

# G-code, read from an uploaded file: what a print will do, and which slicer wrote it. Separate from Library because
# the library will hold other files too (.stl, ...).
#
#   analysis = Gcode::Analysis.new(item.file)
#   analysis.slicer # => a Gcode::Slicer::PrusaSlicer, or nil when the slicer is unknown
module Gcode
end
