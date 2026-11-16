import { gql } from '@apollo/client'

import { PRINTER_FIELDS } from '../../../Dashboard/graphql/dashboard'

// Every field of the About This Printer card, saved or reported
const SPECS_FIELDS = gql`
  fragment PrinterDetailsSpecsFields on PrinterSpecs {
    brand
    model
    firmwareDisplayName
    firmwareVersion
    buildVolume {
      ... on RectangularBuildVolume { x y z }
      ... on CircularBuildVolume { diameter height }
    }
    extruders
    nozzleDiameter
    maxHotendTemp
    maxBedTemp
    heatedBed
    heatedChamber
    webcam
    materials
  }
`

// The details page: the dashboard's printer fields (pushed live by useFleetLiveUpdates), the saved connection and
// specs. Never select octoprintKey, and nothing that calls the printer (version, reportedSpecs): those load apart.
export const PRINTER_DETAILS = gql`
  query PrinterDetails($id: ID!) {
    printer(id: $id) {
      ...DashboardPrinterFields
      uri
      username
      favorite
      specs { ...PrinterDetailsSpecsFields }
    }
  }
  ${PRINTER_FIELDS}
  ${SPECS_FIELDS}
`

// Calls the printer (answer cached 2 hours on the server), so it loads after the page
export const PRINTER_VERSION = gql`
  query PrinterDetailsVersion($id: ID!) {
    printer(id: $id) { id version }
  }
`

// What the printer's server reports, null when it can't be read: the About card's hints and reload buttons. Calls
// the printer (answer cached 2 hours on the server), so it loads after the page
export const REPORTED_SPECS = gql`
  query PrinterDetailsReportedSpecs($id: ID!) {
    printer(id: $id) {
      id
      reportedSpecs { ...PrinterDetailsSpecsFields }
    }
  }
  ${SPECS_FIELDS}
`

// Test Connection with what the form holds; a blank secret is the saved one of `printerId`. Run with the saved
// connection, it also gives the name the server reports (reportedSpecs has none) for the name's reload button.
export const IDENTIFY_SAVED_PRINTER = gql`
  query PrinterDetailsIdentify(
    $backend: PrinterBackend!, $uri: URL!, $username: String, $secret: String, $printerId: ID
  ) {
    identifyPrinter(backend: $backend, uri: $uri, username: $username, secret: $secret, printerId: $printerId) {
      name
      version
    }
  }
`

export const UPDATE_PRINTER = gql`
  mutation PrinterDetailsUpdate($input: UpdatePrinterInput!) {
    updatePrinter(input: $input) {
      printer { id name uri username specs { ...PrinterDetailsSpecsFields } }
      errors
    }
  }
  ${SPECS_FIELDS}
`
