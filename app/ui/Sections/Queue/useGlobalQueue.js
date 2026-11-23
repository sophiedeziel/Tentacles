import { useCallback, useState } from 'react'
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
// first answer), `reload` refetches now and resolves once the answer landed.
//
// `holding` (while a Waiting row is dragged): `queue` stays what it was when the drag started, so a reload's answer
// never reorders the rows under the pointer. The latest answer shows as soon as `holding` goes back to false.
export default function useGlobalQueue ({ holding = false } = {}) {
  // cache-and-network: coming back to the page never shows (and acts on) a queue cached earlier. No deduplication:
  // the reload after an action never joins a request sent before the action was saved.
  const { data, error, refetch } = useQuery(GLOBAL_QUEUE_PAGE, {
    variables: { finished: FINISHED_ROWS },
    fetchPolicy: 'cache-and-network',
    context: { queryDeduplication: false }
  })
  // A failed reload shows as the query's error: nothing to catch here
  const reload = useCallback(() => refetch().catch(() => {}), [refetch])
  const reloadSoon = useDebouncedCallback(reload, REFETCH_DELAY)

  useFleetLiveUpdates(reload)
  useSubscription(QUEUE_CHANGED, { onData: reloadSoon })

  const latest = data?.globalQueue
  // What was shown when holding started. Set while rendering (React's "state from props" pattern), so the render
  // that starts holding already shows it.
  const [held, setHeld] = useState(null)
  if (holding && !held) setHeld({ queue: latest })
  if (!holding && held) setHeld(null)

  return { queue: holding && held ? held.queue : latest, loaded: data !== undefined, error, reload }
}
