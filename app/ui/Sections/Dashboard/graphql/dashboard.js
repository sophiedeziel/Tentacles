import { gql } from '@apollo/client'

// Every printer field the dashboard reads. All are batched (one Redis MGET and one SQL query for the fleet):
// never select octoprintKey, jobStatus, currentJob or octoprintVersion here, they call OctoPrint live.
export const PRINTER_FIELDS = gql`
  fragment DashboardPrinterFields on Printer {
    id
    name
    canStartNext
    queuedCount
    nextJob { id executable { id filename } }
    status {
      stateFamily stateText errorText fileName progress printTimeLeft
      hotend { actual target unit }
      bed { actual target unit }
      camera { enabled streamUrl }
      lastSeenAt updatedAt
    }
  }
`

export const LAYOUT_FIELDS = gql`
  fragment DashboardLayoutFields on Dashboard {
    updatedAt
    sections {
      id
      title
      widgets {
        id
        type
        widthUnits
        heightUnits
        printer { id }
        options {
          ... on PrinterWidgetOptions { camera timeLeft temperatures upNext controls }
          ... on PrintQueueWidgetOptions { nowPrinting startNext rowPerPrinter history }
        }
      }
    }
  }
`

export const DASHBOARD_PAGE = gql`
  query DashboardPage {
    dashboard { ...DashboardLayoutFields }
    monitorHealthy
    printers { ...DashboardPrinterFields }
  }
  ${LAYOUT_FIELDS}
  ${PRINTER_FIELDS}
`

// Polled, so the "Live data paused" banner shows up when the monitor stops after the page loaded
export const MONITOR_HEALTHY = gql`
  query DashboardMonitorHealthy {
    monitorHealthy
  }
`

// Apollo merges each pushed printer into the cache by id, so only its tiles re-render
export const PRINTER_STATUS_CHANGED = gql`
  subscription DashboardPrinterStatusChanged {
    printerStatusChanged { ...DashboardPrinterFields }
  }
  ${PRINTER_FIELDS}
`

// A job was enqueued, removed or changed status: the push carries its printer's queue fields, which Apollo merges
// by id. Queue widgets reload their lists on top of it.
export const PRINT_QUEUE_CHANGED = gql`
  subscription DashboardPrintQueueChanged {
    printQueueChanged { id canStartNext queuedCount nextJob { id executable { id filename } } }
  }
`

export const DASHBOARD_CHANGED = gql`
  subscription DashboardLayoutChanged {
    dashboardChanged { ...DashboardLayoutFields }
  }
  ${LAYOUT_FIELDS}
`

// The layout's widget options are a union
export const POSSIBLE_TYPES = {
  DashboardWidgetOptions: ['PrinterWidgetOptions', 'PrintQueueWidgetOptions']
}

// A status, a layout and widget options have no id of their own. A status keeps the newest snapshot, so a reload
// that answers late can't overwrite a newer push; the others are replaced.
export const TYPE_POLICIES = {
  PrinterStatus: {
    merge: (existing, incoming, { readField }) => (
      !existing || readField('updatedAt', incoming) >= readField('updatedAt', existing)
        ? { ...existing, ...incoming }
        : existing
    )
  },
  Dashboard: { merge: false },
  PrinterWidgetOptions: { merge: false },
  PrintQueueWidgetOptions: { merge: false }
}
