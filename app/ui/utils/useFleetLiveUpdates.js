import { useSubscription } from '@apollo/client/react'

import { PRINT_QUEUE_CHANGED, PRINTER_STATUS_CHANGED } from '../Sections/Dashboard/graphql/dashboard'
import useRefetchWhenStale from '../Sections/Dashboard/utils/useRefetchWhenStale'

// Keeps a page's printers live (the dashboard, the fleet list). Apollo merges each pushed printer into the cache by
// id: printerStatusChanged carries its DashboardPrinterFields, printQueueChanged its queue fields (queuedCount,
// nextJob, canStartNext), and `onQueueChange` runs after each queue push. Pushes can be missed, so `refetch` reloads
// the page's query when the tab comes back and every minute.
export default function useFleetLiveUpdates (refetch, { onQueueChange } = {}) {
  useRefetchWhenStale(refetch)
  useSubscription(PRINTER_STATUS_CHANGED)
  useSubscription(PRINT_QUEUE_CHANGED, { onData: onQueueChange })
}
