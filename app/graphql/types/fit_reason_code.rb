# frozen_string_literal: true

module Types
  # The codes of a ::PrintQueue::Reason of a ::PrintQueue::Fit
  class FitReasonCode < Base::Enum
    description 'Why a printer fits a print job as it does'

    value 'FILAMENT_MATCHES', 'The filament loaded is the one asked for', value: :filament_matches
    value 'ANY_FILAMENT', 'Nothing is asked of the filament: material Not known and Any colour', value: :any_filament
    value 'NO_FILAMENT', 'No filament is loaded in the slot', value: :no_filament
    value 'WRONG_MATERIAL', 'Another material is loaded', value: :wrong_material
    value 'WRONG_COLOUR', 'The material asked for is loaded, in another colour', value: :wrong_colour
    value 'OFFLINE', 'The printer is offline, connecting or in error', value: :offline
    value 'BED_TOO_SMALL', 'Hard limit: the footprint is larger than the bed', value: :bed_too_small
    value 'TOO_TALL', 'Hard limit: the print is taller than the build volume', value: :too_tall
    value 'TOO_FEW_TOOLS', 'Hard limit: the file uses more tools than the printer has', value: :too_few_tools
    value 'MATERIAL_NOT_PRINTED', 'Hard limit: the printer does not print a material it needs',
          value: :material_not_printed
  end
end
