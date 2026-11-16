import { gql } from '@apollo/client'

// The OctoPrint servers on the network, with the saved printer at each address ("Already added as …"). Slow (nmap)
// unless cached; Scan Again asks for a fresh scan.
export const ADD_NETWORK_PRINTERS = gql`
  query AddNetworkPrinters($refresh: Boolean) {
    networkPrinters(refresh: $refresh) { address url printer { id name } }
  }
`

// The approval runs on the server: it asks OctoPrint, polls it and adds the printer. The API key never comes here,
// so never select `printer { octoprintKey }`.
const APP_KEY_REQUEST_FIELDS = 'id address state approvalUrl error printer { id name }'

export const REQUEST_PRINTER_APP_KEY = gql`
  mutation RequestPrinterAppKey($address: String!) {
    requestPrinterAppKey(input: { address: $address }) { request { ${APP_KEY_REQUEST_FIELDS} } errors }
  }
`

export const CANCEL_PRINTER_APP_KEY_REQUEST = gql`
  mutation CancelPrinterAppKeyRequest($id: ID!) {
    cancelPrinterAppKeyRequest(input: { id: $id }) { request { id state } errors }
  }
`

export const PRINTER_APP_KEY_CHANGED = gql`
  subscription PrinterAppKeyChanged($id: ID!) {
    printerAppKeyChanged(id: $id) { ${APP_KEY_REQUEST_FIELDS} }
  }
`

// The manual form: test the connection (never saved), then add the printer
export const IDENTIFY_PRINTER = gql`
  query IdentifyPrinter($backend: PrinterBackend!, $uri: URL!, $username: String, $secret: String!) {
    identifyPrinter(backend: $backend, uri: $uri, username: $username, secret: $secret) { name version }
  }
`

export const ADD_PRINTER = gql`
  mutation AddPrinter($input: AddPrinterInput!) {
    addPrinter(input: $input) { printer { id name } errors }
  }
`
