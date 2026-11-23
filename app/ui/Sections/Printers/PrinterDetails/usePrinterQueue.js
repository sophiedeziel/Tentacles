import { useCallback } from 'react'
import { useQuery, useSubscription } from '@apollo/client/react'

import useDebouncedCallback from '../../../utils/useDebouncedCallback'
import useRefetchWhenStale from '../../../utils/useRefetchWhenStale'
import { REFETCH_DELAY } from '../../Queue/useGlobalQueue'
import { QUEUE_CHANGED } from '../../Queue/graphql/queue'
import { PRINTER_QUEUE } from './graphql/printerQueue'

// The printer page's part of the global queue, kept live like the queue page's: queueChanged reloads it (bursts
// coalesced by REFETCH_DELAY), and it reloads when the tab comes back and every minute, for pushes missed. The
// printer's status stays live through the page's own useFleetLiveUpdates.
//
// Nothing is asked while `enabled` is false (the global queue is off). Returns { printer, dispatchPaused, loaded,
// reload }: `printer` is null until the first answer (or when the printer is gone), `reload` refetches now and
// resolves once the answer landed.
export default function usePrinterQueue (printerId, { enabled }) {
  // cache-and-network: never shows a queue cached earlier. No deduplication: the reload after an action never joins a
  // request sent before the action was saved.
  const { data: latest, previousData, refetch } = useQuery(PRINTER_QUEUE, {
    variables: { id: printerId },
    skip: !enabled,
    fetchPolicy: 'cache-and-network',
    context: { queryDeduplication: false }
  })
  // While it refetches because the cache lost a field (a filament changed: its count went with it), the last answer
  // stays: the queue's part doesn't blink out
  const data = enabled ? latest ?? previousData : undefined
  // A failed reload keeps what is shown: nothing to catch here
  const reload = useCallback(() => (enabled ? refetch().catch(() => {}) : Promise.resolve()), [enabled, refetch])
  const reloadSoon = useDebouncedCallback(reload, REFETCH_DELAY)

  useRefetchWhenStale(reload)
  useSubscription(QUEUE_CHANGED, { skip: !enabled, onData: reloadSoon })

  return {
    printer: data?.printer ?? null,
    dispatchPaused: Boolean(data?.globalQueue?.dispatchPaused),
    loaded: data !== undefined,
    reload
  }
}
