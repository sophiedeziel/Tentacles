import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Alert, App, Button, Card, Skeleton, Switch, Tooltip, Typography } from 'antd'
import { PauseCircleOutlined, PlusOutlined } from '@ant-design/icons'

import EmptyState from '../../components/EmptyState/EmptyState'
import useNow from '../../utils/useNow'
import { useBedCleared } from './BedCleared'
import { useCopies } from './Copies'
import { PrintingMenu } from './menus'
import { Muted } from './parts'
import { AvailablePrinters } from './PrinterTables'
import { Finished, Printing } from './PrintTables'
import { Waiting } from './WaitingTable'
import { isQueueEmpty } from './queueView'
import useGlobalQueue from './useGlobalQueue'
import useQueueActions from './useQueueActions'
import * as classes from './QueuePage.module.less'

const DESCRIPTION = 'One queue for every printer. A free printer takes the first job it can print with the filament ' +
  'it has loaded.'

// Reconnect is OctoPrint's (PrusaLink connects to its printer on its own): a printer in error reconnects, an offline
// one connects again. Nothing while it is connecting.
const canReconnect = (printer) => printer.backend === 'OCTOPRINT' &&
  ['OFFLINE', 'ERROR', undefined].includes(printer.status?.stateFamily)

// There is no screen to add files to the queue yet: Add to Queue is shown, disabled, where it will go
function AddToQueue () {
  return (
    <Tooltip title="Coming soon">
      <span><Button type="primary" icon={<PlusOutlined />} disabled>Add to Queue</Button></span>
    </Tooltip>
  )
}

// A button that runs `action` (resolving once done), loading meanwhile
function ActionButton ({ action, children, ...props }) {
  const [busy, setBusy] = useState(false)
  const run = async () => {
    setBusy(true)
    await action()
    setBusy(false)
  }
  return <Button size="small" loading={busy} onClick={run} {...props}>{children}</Button>
}

// Dispatch hands waiting copies to free printers. The switch shows dispatchPaused from the page's query: it pauses
// or resumes dispatch, then shows the state reloaded.
function DispatchSwitch ({ paused, actions }) {
  const [switching, setSwitching] = useState(false)
  const toggle = async (on) => {
    setSwitching(true)
    await (on ? actions.resumeDispatch() : actions.pauseDispatch())
    setSwitching(false)
  }

  return (
    <span className={classes.dispatch}>
      <Switch checked={!paused} loading={switching} onChange={toggle} aria-label="Dispatch" />
      <span>{paused ? 'Dispatch paused' : 'Dispatching jobs'}</span>
    </span>
  )
}

// The title and what the queue does; the dispatch switch and Add to Queue on the right, once there is a queue
function Header ({ paused, actions, tools = true }) {
  return (
    <div className={classes.header}>
      <div className={classes.heading}>
        <Typography.Title level={3} style={{ margin: 0 }}>Print Queue</Typography.Title>
        <Muted>{DESCRIPTION}</Muted>
      </div>
      {tools && (
        <div className={classes.tools}>
          <DispatchSwitch paused={paused} actions={actions} />
          <AddToQueue />
        </div>
      )}
    </div>
  )
}

// Above the lists while dispatch is paused: what still happens, how many prints wait for it, and Resume Dispatch
function PausedBanner ({ waitingPrints, onResume }) {
  const waiting = waitingPrints > 0 ? `, so ${waitingPrints} ${waitingPrints === 1 ? 'print stays' : 'prints stay'} waiting` : ''
  return (
    <Alert type="warning" showIcon icon={<PauseCircleOutlined />} className={classes.banner}
      title="Dispatch is paused"
      description={`Prints under way keep going. No printer takes a new job until you resume${waiting}. You can still ` +
        'add, reorder and hold jobs.'}
      action={<ActionButton type="primary" size="middle" action={onResume}>Resume Dispatch</ActionButton>} />
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
  // While a Waiting row is dragged, reloads are held until the drop
  const [dragging, setDragging] = useState(false)
  // The Waiting row to show (Show Batch in Waiting): its id, and when it was asked for
  const [reveal, setReveal] = useState(null)
  const { queue, loaded, error, reload } = useGlobalQueue({ holding: dragging })
  const actions = useQueueActions(reload)
  const bedCleared = useBedCleared({ dispatchPaused: !!queue?.dispatchPaused, onDone: reload })
  const copies = useCopies({ onSave: actions.setCopies })
  const now = useNow()

  if (error && !loaded) return <Alert type="error" title="Could not load the print queue" description={error.message} />
  if (!loaded) return <Skeleton active />
  if (!queue) return <Alert type="info" title="The print queue is off" />

  const paused = queue.dispatchPaused
  const empty = isQueueEmpty(queue)
  const waitingPrints = queue.waiting.reduce((total, job) => total + job.copiesLeftToStart, 0)
  const waitingById = new Map(queue.waiting.map((job) => [job.id, job]))
  // The copies dialog of a print job, with its Waiting row's copies when it has one
  const askCopies = (job) => copies.ask(waitingById.get(job.id) || job)
  const show = (job) => setReveal({ id: job.id, at: Date.now() })

  return (
    <div className={classes.page}>
      <Header paused={paused} actions={actions} tools={!empty} />
      {paused && <PausedBanner waitingPrints={waitingPrints} onResume={actions.resumeDispatch} />}
      {empty
        ? <EmptyQueue />
        : (
          <>
            <AvailablePrinters toClear={queue.printersToClear} available={queue.availablePrinters}
              offline={queue.offlinePrinters} paused={paused}
              renderAction={(printer, { toClear }) => toClear && (
                <Button type="primary" size="small" onClick={() => bedCleared.ask(printer)}>Bed Cleared</Button>
              )}
              renderOfflineAction={(printer) => canReconnect(printer) && (
                <ActionButton action={() => actions.reconnect(printer)}>Reconnect</ActionButton>
              )} />
            <Printing prints={queue.printing} now={now}
              renderMenu={(print) => <PrintingMenu print={print} actions={actions} onCopies={askCopies} onShow={show} />} />
            <Waiting jobs={queue.waiting} paused={paused} printing={queue.printing} now={now} actions={actions}
              onCopies={askCopies} reveal={reveal} onDragChange={setDragging} />
            <Finished prints={queue.finished} now={now}
              renderAction={(print) => ['FAILED', 'CANCELLED'].includes(print.result) && (
                <ActionButton action={() => actions.requeue(print.printJob.file)} disabled={print.printJob.file.isDeleted}
                  aria-label={`Requeue ${print.printJob.file.filename}`}>
                  Requeue
                </ActionButton>
              )} />
          </>
          )}
      {bedCleared.modal}
      {copies.modal}
    </div>
  )
}

const actionsShape = PropTypes.shape({ pauseDispatch: PropTypes.func.isRequired, resumeDispatch: PropTypes.func.isRequired })
ActionButton.propTypes = { action: PropTypes.func.isRequired, children: PropTypes.node.isRequired }
DispatchSwitch.propTypes = { paused: PropTypes.bool.isRequired, actions: actionsShape.isRequired }
Header.propTypes = { paused: PropTypes.bool.isRequired, actions: actionsShape.isRequired, tools: PropTypes.bool }
PausedBanner.propTypes = { waitingPrints: PropTypes.number.isRequired, onResume: PropTypes.func.isRequired }

// The global print queue, at /queue (only while its flag is on): available printers (beds to clear first), printing,
// waiting and finished, from one query kept live by useGlobalQueue, with their actions (useQueueActions)
export default function QueuePage () {
  return <App><QueueContent /></App>
}
