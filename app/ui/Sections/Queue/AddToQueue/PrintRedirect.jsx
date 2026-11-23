import React from 'react'
import { Navigate, useParams } from 'react-router'

import useQueueEnabled from '../useQueueEnabled'

// /files/:id/print, the old print page's address: Add to Queue while the global queue is on, the file's page
// otherwise. Renders nothing until the flag is known, so neither page flashes.
export default function PrintRedirect () {
  const { id } = useParams()
  const queue = useQueueEnabled()
  if (queue.loading) return null

  return <Navigate to={queue.enabled ? `/queue/add/${id}` : `/files/${id}`} replace />
}
