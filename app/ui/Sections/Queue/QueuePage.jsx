import React from 'react'
import PropTypes from 'prop-types'
import { Alert, App, Button, Skeleton, Switch, Tooltip, Typography } from 'antd'
import { PlusOutlined } from '@ant-design/icons'

import EmptyState from '../../components/EmptyState/EmptyState'
import useNow from '../../utils/useNow'
import { Muted } from './parts'
import { AvailablePrinters, PrintersToClear } from './PrinterTables'
import { Finished, Printing } from './PrintTables'
import { Waiting } from './WaitingTable'
import { isQueueEmpty, lastPrintByPrinter } from './queueView'
import useGlobalQueue from './useGlobalQueue'
import * as classes from './QueuePage.module.less'

const DESCRIPTION = 'Files wait here in order, and each goes to the next printer that can print it.'

// Dispatch hands waiting copies to free printers. Shown as it is: pausing and resuming come with the page's actions.
function DispatchSwitch ({ paused }) {
  return (
    <span className={classes.dispatch}>
      <Switch checked={!paused} disabled aria-label="Dispatch" />
      <span>{paused ? 'Dispatch paused' : 'Dispatch on'}</span>
    </span>
  )
}

function Header ({ paused }) {
  return (
    <div className={classes.header}>
      <div className={classes.heading}>
        <Typography.Title level={3} style={{ margin: 0 }}>Print Queue</Typography.Title>
        <Muted>{DESCRIPTION}</Muted>
      </div>
      <DispatchSwitch paused={paused} />
    </div>
  )
}

// Nothing waiting, printing or to clear. There is no screen to add files to the queue yet: Add to Queue is shown,
// disabled, where it will go.
function EmptyQueue () {
  return (
    <section aria-label="Nothing in the queue" className={classes.empty}>
      <EmptyState kind="queue" title="Nothing in the queue"
        description="Queued files wait here, then print on the next printer that can take them.">
        <Tooltip title="Coming soon">
          <Button type="primary" icon={<PlusOutlined />} disabled>Add to Queue</Button>
        </Tooltip>
      </EmptyState>
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

  return (
    <div className={classes.page}>
      <Header paused={paused} />
      {paused && (
        <Alert type="warning" showIcon title="Dispatch is paused"
          description="No copy starts until dispatch resumes. Jobs can still be added, reordered and held." />
      )}
      {isQueueEmpty(queue)
        ? <EmptyQueue />
        : (
          <>
            {queue.printersToClear.length > 0 && (
              <PrintersToClear printers={queue.printersToClear} lastPrints={lastPrintByPrinter(queue.finished)} />
            )}
            <AvailablePrinters printers={queue.availablePrinters} />
            <Printing prints={queue.printing} now={now} />
            <Waiting jobs={queue.waiting} paused={paused} />
            <Finished prints={queue.finished} now={now} />
          </>
          )}
    </div>
  )
}

DispatchSwitch.propTypes = { paused: PropTypes.bool.isRequired }
Header.propTypes = { paused: PropTypes.bool.isRequired }

// The global print queue, at /queue (only while its flag is on): printers waiting to be cleared, available printers,
// printing, waiting and finished, from one query kept live by useGlobalQueue
export default function QueuePage () {
  return <App><QueueContent /></App>
}
