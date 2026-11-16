import { gql } from '@apollo/client'

import { PRINTER_FIELDS } from '../../../Dashboard/graphql/dashboard'

// The fleet list: the dashboard's printer fields (pushed live by useFleetLiveUpdates) and the saved columns the
// table shows. Never select version, jobStatus or reportedSpecs here: they call the printer.
export const FLEET_PAGE = gql`
  query FleetPage {
    printers {
      ...DashboardPrinterFields
      uri
      favorite
      specs {
        brand
        model
        buildVolume {
          ... on RectangularBuildVolume { x y z }
          ... on CircularBuildVolume { diameter height }
        }
      }
    }
  }
  ${PRINTER_FIELDS}
`

// The OctoPrint servers on the network, with the saved printer at each address. Slow (nmap) unless cached, so it
// loads apart from the table; Scan Network asks for a fresh scan.
export const NETWORK_PRINTERS = gql`
  query FleetNetworkPrinters($refresh: Boolean) {
    networkPrinters(refresh: $refresh) { address url printer { id } }
  }
`

export const SET_PRINTER_FAVORITE = gql`
  mutation FleetSetPrinterFavorite($id: ID!, $favorite: Boolean!) {
    setPrinterFavorite(input: { id: $id, favorite: $favorite }) { printer { id favorite } errors }
  }
`

export const REMOVE_PRINTER = gql`
  mutation FleetRemovePrinter($id: ID!) {
    removePrinter(input: { id: $id }) { removedPrinterId errors }
  }
`
