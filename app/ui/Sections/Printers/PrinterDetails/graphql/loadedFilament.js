import { gql } from '@apollo/client'

export const LOADED_FILAMENT_FIELDS = gql`
  fragment LoadedFilamentFields on LoadedFilament {
    slot
    material
    colour
    updatedAt
  }
`

// The Loaded Filament card: the printer's filaments, its materials spec (listed first) and the options to pick from
export const LOADED_FILAMENT = gql`
  query LoadedFilament($printerId: ID!) {
    printer(id: $printerId) {
      id
      specs { materials }
      loadedFilaments { ...LoadedFilamentFields }
    }
    filamentMaterials
    filamentColours
  }
  ${LOADED_FILAMENT_FIELDS}
`

// Set or cleared in another window: the server pushes printerStatusChanged, and this selection makes the push carry
// the printer's filaments, which Apollo merges by id (the fleet's own subscription selects DashboardPrinterFields)
export const LOADED_FILAMENT_CHANGED = gql`
  subscription LoadedFilamentChanged {
    printerStatusChanged {
      id
      loadedFilaments { ...LoadedFilamentFields }
    }
  }
  ${LOADED_FILAMENT_FIELDS}
`

export const SET_LOADED_FILAMENT = gql`
  mutation SetLoadedFilament($input: SetLoadedFilamentInput!) {
    setLoadedFilament(input: $input) {
      printer { id loadedFilaments { ...LoadedFilamentFields } }
      errors { field message }
    }
  }
  ${LOADED_FILAMENT_FIELDS}
`

export const CLEAR_LOADED_FILAMENT = gql`
  mutation ClearLoadedFilament($input: ClearLoadedFilamentInput!) {
    clearLoadedFilament(input: $input) {
      printer { id loadedFilaments { ...LoadedFilamentFields } }
      errors { field message }
    }
  }
  ${LOADED_FILAMENT_FIELDS}
`
