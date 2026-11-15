import { gql } from '@apollo/client'

// The printer controls. Each returns the errors to show; the printer's new state arrives through
// printerStatusChanged, not from the payload. The expectations name what the user confirmed, so the server refuses
// when the printer moved on (another file printing, another job first in the queue).
const fileAction = (mutation, operation) => gql`
  mutation Dashboard${operation}($printerId: ID!, $expectedFileName: String) {
    ${mutation}(input: { printerId: $printerId, expectedFileName: $expectedFileName }) { success errors }
  }
`

const connectAction = (mutation, operation) => gql`
  mutation Dashboard${operation}($printerId: ID!) {
    ${mutation}(input: { printerId: $printerId }) { success errors }
  }
`

const START_NEXT = gql`
  mutation DashboardStartNextPrint($printerId: ID!, $expectedJobId: ID) {
    startNextPrint(input: { printerId: $printerId, expectedJobId: $expectedJobId }) { success errors }
  }
`

const confirmedFile = (printer) => ({ expectedFileName: printer.status.fileName })

export const ACTIONS = {
  pause: { mutation: 'pausePrint', document: fileAction('pausePrint', 'PausePrint'), expectations: confirmedFile },
  resume: { mutation: 'resumePrint', document: fileAction('resumePrint', 'ResumePrint'), expectations: confirmedFile },
  cancel: { mutation: 'cancelPrint', document: fileAction('cancelPrint', 'CancelPrint'), expectations: confirmedFile },
  startNext: {
    mutation: 'startNextPrint', document: START_NEXT, expectations: (printer) => ({ expectedJobId: printer.nextJob?.id })
  },
  connect: { mutation: 'connectPrinter', document: connectAction('connectPrinter', 'ConnectPrinter') },
  reconnect: { mutation: 'reconnectPrinter', document: connectAction('reconnectPrinter', 'ReconnectPrinter') }
}
