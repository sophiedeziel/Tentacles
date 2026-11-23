import { gql } from '@apollo/client'

// Every printer field the dashboard reads. All are batched (one Redis MGET and one SQL query for the fleet):
// never select jobStatus, currentJob or version here, they call the printer live.
export const PRINTER_FIELDS = gql`
  fragment DashboardPrinterFields on Printer {
    id
    name
    backend
    canStartNext
    queuedCount
    nextJob { id executable { id filename } }
    status {
      stateFamily stateText serverReachable errorText fileName progress printTimeLeft
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

// Reset Layout: the default layout, unsaved (every id is null)
export const DEFAULT_DASHBOARD = gql`
  query DashboardDefault {
    defaultDashboard { ...DashboardLayoutFields }
  }
  ${LAYOUT_FIELDS}
`

// Done: replaces the whole layout. `dashboard` is null and `errors` says why when nothing was saved.
export const SAVE_DASHBOARD = gql`
  mutation SaveDashboard($sections: [DashboardSectionInput!]!) {
    saveDashboard(input: { sections: $sections }) {
      dashboard { ...DashboardLayoutFields }
      errors
    }
  }
  ${LAYOUT_FIELDS}
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

// The layout's widget options and a printer's build volume are unions
export const POSSIBLE_TYPES = {
  DashboardWidgetOptions: ['PrinterWidgetOptions', 'PrintQueueWidgetOptions'],
  BuildVolume: ['RectangularBuildVolume', 'CircularBuildVolume']
}

const FILAMENT_KEYS = ['slot', 'material', 'colour']

// See TYPE_POLICIES.Printer.fields.loadedFilaments
function mergeLoadedFilaments (existing = [], incoming, { readField, mergeObjects }) {
  return incoming.map((filament) => {
    const same = existing.find((old) => FILAMENT_KEYS.every((key) => readField(key, old) === readField(key, filament)))
    return same ? mergeObjects(same, filament) : filament
  })
}

// A status, a layout, widget options and specs have no id of their own. A status keeps the newest snapshot, so a
// reload that answers late can't overwrite a newer push; specs merge (pages select different fields of them); the
// others are replaced.
export const TYPE_POLICIES = {
  PrinterStatus: {
    merge: (existing, incoming, { readField }) => (
      !existing || readField('updatedAt', incoming) >= readField('updatedAt', existing)
        ? { ...existing, ...incoming }
        : existing
    )
  },
  PrinterSpecs: { merge: true },
  Printer: {
    fields: {
      // A list without ids, always sent whole: replaced, even by a shorter one (a removed filament), in the incoming
      // order. A filament sent again unchanged (same slot, material and colour) keeps the fields the incoming
      // selection lacks: the Loaded Filament card and its printerStatusChanged push don't select
      // waitingJobsAskingCount, the printer page's queue query does, and would otherwise lose it on every push. A
      // changed filament starts over: the count was for the old one (the queue query refetches what it misses).
      loadedFilaments: { merge: mergeLoadedFilaments },
      // Lists the printer page refetches whole: replaced, even by a shorter one
      upNext: { merge: false },
      skipped: { merge: false }
    }
  },
  Dashboard: { merge: false },
  // No id, one per fleet: the menu's flag check (dispatchPaused alone) and the queue page's sections merge into it
  GlobalQueue: { merge: true },
  PrinterWidgetOptions: { merge: false },
  PrintQueueWidgetOptions: { merge: false }
}
