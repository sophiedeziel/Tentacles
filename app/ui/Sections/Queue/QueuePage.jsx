import React from 'react'
import PropTypes from 'prop-types'
import { Alert, App, Button, Card, Skeleton, Switch, Tooltip, Typography } from 'antd'
import { PauseCircleOutlined, PlusOutlined } from '@ant-design/icons'

import EmptyState from '../../components/EmptyState/EmptyState'
import useNow from '../../utils/useNow'
import { Muted } from './parts'
import { AvailablePrinters } from './PrinterTables'
import { Finished, Printing } from './PrintTables'
import { Waiting } from './WaitingTable'
import { isQueueEmpty, lastPrintByPrinter } from './queueView'
import useGlobalQueue from './useGlobalQueue'
import * as classes from './QueuePage.module.less'

const DESCRIPTION = 'One queue for every printer. A free printer takes the first job it can print with the filament ' +
  'it has loaded.'

// There is no screen to add files to the queue yet: Add to Queue is shown, disabled, where it will go
function AddToQueue () {
  return (
    <Tooltip title="Coming soon">
      <span><Button type="primary" icon={<PlusOutlined />} disabled>Add to Queue</Button></span>
    </Tooltip>
  )
}

// Dispatch hands waiting copies to free printers. Shown as it is: pausing and resuming come with the page's actions.
function DispatchSwitch ({ paused }) {
  return (
    <span className={classes.dispatch}>
      <Switch checked={!paused} disabled aria-label="Dispatch" />
      <span>{paused ? 'Dispatch paused' : 'Dispatching jobs'}</span>
    </span>
  )
}

// The title and what the queue does; the dispatch switch and Add to Queue on the right, once there is a queue
function Header ({ paused, tools = true }) {
  return (
    <div className={classes.header}>
      <div className={classes.heading}>
        <Typography.Title level={3} style={{ margin: 0 }}>Print Queue</Typography.Title>
        <Muted>{DESCRIPTION}</Muted>
      </div>
      {tools && (
        <div className={classes.tools}>
          <DispatchSwitch paused={paused} />
          <AddToQueue />
        </div>
      )}
    </div>
  )
}

// Above the lists while dispatch is paused: what still happens, how many prints wait for it, and Resume Dispatch
function PausedBanner ({ waitingPrints }) {
  const waiting = waitingPrints > 0 ? `, so ${waitingPrints} ${waitingPrints === 1 ? 'print stays' : 'prints stay'} waiting` : ''
  return (
    <Alert type="warning" showIcon icon={<PauseCircleOutlined />} className={classes.banner}
      title="Dispatch is paused"
      description={`Prints under way keep going. No printer takes a new job until you resume${waiting}. You can still ` +
        'add, reorder and hold jobs.'}
      action={<Button type="primary" disabled>Resume Dispatch</Button>} />
  )
}

// Nothing waiting, printing or to clear
function EmptyQueue () {
  return (
    <section aria-label="The queue is empty">
      <Card styles={{ body: { padding: '56px 24px' } }}>
        <EmptyState kind="queue" title="The queue is empty"
          description="Add a file and say how many copies you need. Printers with the right filament pick the prints up on their own.">
          <AddToQueue />
        </EmptyState>
      </Card>
    </section>
  )
}

function QueueContent () {
  const { queue, loaded, error } = useGlobalQueue()
  const now = useNow()

  if (error && !loaded) return <Alert type="error" title="Could not load the print queue" description={error.message} />
  if (!loaded) return <Skeleton active />
  if (!queue) return <Alert type="info" title="The print queue is off" />

  const paused = queue.dispatchPaused
  const empty = isQueueEmpty(queue)
  const waitingPrints = queue.waiting.reduce((total, job) => total + job.copiesLeftToStart, 0)

  return (
    <div className={classes.page}>
      <Header paused={paused} tools={!empty} />
      {paused && <PausedBanner waitingPrints={waitingPrints} />}
      {empty
        ? <EmptyQueue />
        : (
          <>
            <AvailablePrinters toClear={queue.printersToClear} available={queue.availablePrinters}
              offline={queue.offlinePrinters} paused={paused} onBed={lastPrintByPrinter(queue.finished)} />
            <Printing prints={queue.printing} now={now} />
            <Waiting jobs={queue.waiting} paused={paused} printing={queue.printing} now={now} />
            <Finished prints={queue.finished} now={now} />
          </>
          )}
    </div>
  )
}

DispatchSwitch.propTypes = { paused: PropTypes.bool.isRequired }
Header.propTypes = { paused: PropTypes.bool.isRequired, tools: PropTypes.bool }
PausedBanner.propTypes = { waitingPrints: PropTypes.number.isRequired }

// The global print queue, at /queue (only while its flag is on): available printers (beds to clear first), printing,
// waiting and finished, from one query kept live by useGlobalQueue
export default function QueuePage () {
  return <App><QueueContent /></App>
}
