import { useQuery } from '@apollo/client/react'

import { GLOBAL_QUEUE_ENABLED } from './graphql/queue'

// Whether the global print queue is on (globalQueue is null while its flag is off), for the side menu and the
// routes. Cached: every caller shares one request. `loading` until the answer comes; a failed check reads as off.
export default function useQueueEnabled () {
  const { data, loading } = useQuery(GLOBAL_QUEUE_ENABLED)
  return { enabled: Boolean(data?.globalQueue), loading }
}
