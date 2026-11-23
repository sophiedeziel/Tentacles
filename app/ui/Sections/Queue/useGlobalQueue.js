import { useCallback } from 'react'
import { useQuery, useSubscription } from '@apollo/client/react'

import useDebouncedCallback from '../../utils/useDebouncedCallback'
import useFleetLiveUpdates from '../../utils/useFleetLiveUpdates'
import { FINISHED_ROWS, GLOBAL_QUEUE_PAGE, QUEUE_CHANGED } from './graphql/queue'

// How long after the last queueChanged push the page reloads: a burst (ten copies handed out by one dispatch pass)
// reloads once
export const REFETCH_DELAY = 300

// The /queue page's data, kept live:
// - queueChanged (fleet level, small payload) reloads globalQueue, debounced by REFETCH_DELAY
// - printerStatusChanged merges each printer's status into the cache by id (useFleetLiveUpdates), so the progress
//   of a print needs no queue push
// - the page reloads when the tab comes back and every minute, for pushes missed
//
// Returns { queue, loaded, error, reload }: `queue` is globalQueue (null when the flag is off, undefined until the
// first answer), `reload` refetches now. The actions (drag to reorder) can hold a reload's result here while a row
// is dragged, and apply it on drop.
export default function useGlobalQueue () {
  // cache-and-network: coming back to the page never shows (and acts on) a queue cached earlier
  const { data, error, refetch } = useQuery(GLOBAL_QUEUE_PAGE, {
    variables: { finished: FINISHED_ROWS },
    fetchPolicy: 'cache-and-network'
  })
  // A failed reload shows as the query's error: nothing to catch here
  const reload = useCallback(() => refetch().catch(() => {}), [refetch])
  const reloadSoon = useDebouncedCallback(reload, REFETCH_DELAY)

  useFleetLiveUpdates(reload)
  useSubscription(QUEUE_CHANGED, { onData: reloadSoon })

  return { queue: data?.globalQueue, loaded: data !== undefined, error, reload }
}
