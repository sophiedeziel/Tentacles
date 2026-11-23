import React, { useEffect } from 'react'
import PropTypes from 'prop-types'
import { useNavigate, useParams } from 'react-router'
import { useQuery } from '@apollo/client/react'
import { Alert, App, Skeleton, Typography } from 'antd'
import { ArrowLeftOutlined } from '@ant-design/icons'

import { QueueLink } from '../parts'
import { copiesFloor } from '../queueView'
import { useQueueMutation } from '../useQueueActions'
import { HOLD_PRINT_JOB, RELEASE_PRINT_JOB } from '../graphql/actions'
import { EDIT_PRINT_JOB, UPDATE_PRINT_JOB } from './graphql/addToQueue'
import { editedJob, updateVariables } from './formRules'
import { POLL_INTERVAL } from './AddToQueuePage'
import QueueJobForm from './QueueJobForm'
import * as classes from './AddToQueue.module.less'

const { Text } = Typography

const submitLabel = () => 'Save Changes'

function Heading ({ filename }) {
  return (
    <div className={classes.heading}>
      <QueueLink to="/queue"><ArrowLeftOutlined /> Print Queue</QueueLink>
      <h1>{filename ? `Edit ${filename} in the Queue` : 'Edit a Job in the Queue'}</h1>
      <Text type="secondary">Changes apply to the copies still waiting. The job keeps its place in the queue.</Text>
    </div>
  )
}

function Gone ({ title }) {
  return (
    <Alert type="info" title={title}
      description={<>Its copies are printing or finished. <QueueLink to="/queue">Back to the Print Queue</QueueLink></>} />
  )
}

function EditJobContent () {
  const { printJobId } = useParams()
  const navigate = useNavigate()
  const save = useQueueMutation(null)
  const { data, error, startPolling, stopPolling } = useQuery(EDIT_PRINT_JOB, {
    variables: { id: printJobId },
    // The form starts from what is saved now, not from what an earlier visit left in the cache
    fetchPolicy: 'network-only'
  })
  const job = data?.globalQueue?.printJob
  const pending = job?.file.gcodeSummary?.status === 'PENDING'

  // A summary being read is asked for again until it is ready or failed, like on the Add to Queue page
  useEffect(() => {
    if (!pending) return undefined
    startPolling(POLL_INTERVAL)
    return () => stopPolling()
  }, [pending, startPolling, stopPolling])

  // Saves the options (updatePrintJob), then the hold when it changed (it is not one of updatePrintJob's options).
  // Refused, the reason shows and the page stays.
  const update = async (variables) => {
    const saved = await save(UPDATE_PRINT_JOB, updateVariables(job.id, variables), 'updatePrintJob',
      { failure: 'The changes could not be saved' })
    if (!saved) return false
    if (variables.held !== job.held) {
      const [document, field] = variables.held
        ? [HOLD_PRINT_JOB, 'holdPrintJob']
        : [RELEASE_PRINT_JOB, 'releasePrintJob']
      const held = await save(document, { id: job.id }, field, { failure: variables.held ? 'Hold failed' : 'Release failed' })
      if (!held) return false
    }
    navigate('/queue')
    return true
  }

  let content
  if (!data) {
    content = error
      ? <Alert type="error" title="Could not load the job" description={error.message} />
      : <Skeleton active />
  } else if (!job) {
    content = <Gone title="This job is no longer in the queue" />
  } else if (job.copiesLeftToStart === 0) {
    content = <Gone title="Nothing of this job is waiting any more" />
  } else {
    content = (
      <QueueJobForm key={job.id} mode="edit" file={job.file} materials={data.filamentMaterials}
        colours={data.filamentColours} initial={editedJob(job)} printJobId={job.id} minCopies={copiesFloor(job)}
        waitingPosition={job.waitingPosition} submitLabel={submitLabel} cancelLabel="Discard Changes"
        onSubmit={update} onCancel={() => navigate('/queue')} />
    )
  }

  return (
    <div className={classes.page}>
      <Heading filename={job?.file.filename} />
      {content}
    </div>
  )
}

// The Edit page of a waiting job, at /queue/:printJobId/edit (only while the global queue's flag is on), from Edit
// Printers and Options in its "⋯" menu: the Add to Queue form in its edit mode (QueueJobForm), started from the job's
// saved options. The changes apply to the copies still waiting; its place is read-only. Saved, it goes back to the
// queue; Discard Changes goes back without saving.
export default function EditJobPage () {
  return <App><EditJobContent /></App>
}

Heading.propTypes = { filename: PropTypes.string }
Gone.propTypes = { title: PropTypes.string.isRequired }
