import React, { useEffect } from 'react'
import { useNavigate, useParams } from 'react-router'
import { useQuery } from '@apollo/client/react'
import { Alert, App, Skeleton, Typography } from 'antd'
import { ArrowLeftOutlined } from '@ant-design/icons'

import { QueueLink } from '../parts'
import { useQueueMutation } from '../useQueueActions'
import { ADD_PRINT_JOB, ADD_TO_QUEUE_FILE } from './graphql/addToQueue'
import QueueJobForm from './QueueJobForm'
import * as classes from './AddToQueue.module.less'

const { Text } = Typography

// How often a file whose G-code is still being read is asked for again
export const POLL_INTERVAL = 3000

const submitLabel = (copies) => (copies > 1 ? `Add ${copies} Prints to Queue` : 'Add to Queue')

function Heading () {
  return (
    <div className={classes.heading}>
      <QueueLink to="/queue"><ArrowLeftOutlined /> Back</QueueLink>
      <h1>Add to Queue</h1>
      <Text type="secondary">Say what the print needs. The queue finds the printers.</Text>
    </div>
  )
}

function AddToQueueContent () {
  const { fileId } = useParams()
  const navigate = useNavigate()
  const save = useQueueMutation(null)
  const { data, error, startPolling, stopPolling } = useQuery(ADD_TO_QUEUE_FILE, { variables: { fileId } })
  const file = data?.file
  const pending = file?.gcodeSummary?.status === 'PENDING'

  // A summary being read is asked for again until it is ready or failed: what it says fills the empty fields
  useEffect(() => {
    if (!pending) return undefined
    startPolling(POLL_INTERVAL)
    return () => stopPolling()
  }, [pending, startPolling, stopPolling])

  const add = async (variables) => {
    const saved = await save(ADD_PRINT_JOB, { fileId, ...variables }, 'addToQueue', { failure: 'It could not be added' })
    if (saved) navigate('/queue')
    return saved
  }

  let content
  if (!data) {
    content = error
      ? <Alert type="error" title="Could not load the file" description={error.message} />
      : <Skeleton active />
  } else if (!file || file.isDeleted) {
    content = <Alert type="warning" title="This file is no longer in the library" />
  } else if (!file.gcodeSummary) {
    content = <Alert type="warning" title="Only G-code files can be queued" description="A model has to be sliced before it can be queued." />
  } else {
    content = (
      <QueueJobForm file={file} materials={data.filamentMaterials} colours={data.filamentColours}
        submitLabel={submitLabel} onSubmit={add} onCancel={() => navigate('/queue')} />
    )
  }

  return (
    <div className={classes.page}>
      <Heading />
      {content}
    </div>
  )
}

// Add to Queue, at /queue/add/:fileId (only while the global queue's flag is on): the options of a new job for one
// G-code file (QueueJobForm). Saved, it goes back to the queue; refused, the server's reason shows and the form stays.
export default function AddToQueuePage () {
  return <App><AddToQueueContent /></App>
}
