import React, { useId, useState } from 'react'
import PropTypes from 'prop-types'
import { Alert, Button, Switch, Table, Tag } from 'antd'

import { useBedCleared } from '../../Queue/BedCleared'
import { FileName, Muted, QueueSection } from '../../Queue/parts'
import { batchView } from '../../Queue/queueView'
import useQueueActions, { useQueueMutation } from '../../Queue/useQueueActions'
import { Needs, WhatHappensNextCell } from '../../Queue/WaitingTable'
import { SET_PRINTER_TAKES_JOBS } from './graphql/printerQueue'
import * as classes from './PrinterDetails.module.less'

// The print still on the bed, and Bed Cleared (the queue page's modal and wording): the printer takes nothing from
// the queue until then
function BedBanner ({ printer, onBedCleared }) {
  const filename = printer.printOnBed?.printJob?.file.filename
  return (
    <Alert type="warning" showIcon
      title={filename ? `${filename} is still on the bed` : 'The last print is still on the bed'}
      description={`Clear it, then confirm: ${printer.name} takes no job from the queue until then.`}
      action={<Button size="small" onClick={() => onBedCleared(filename)}>Bed Cleared</Button>} />
  )
}

// Saved at once, apart from the page's form. A refusal shows as a message (useQueueMutation); the switch shows what
// the server has.
function TakesJobs ({ printer, reload }) {
  const id = useId()
  const run = useQueueMutation(reload)
  const [saving, setSaving] = useState(false)

  const change = async (takesJobs) => {
    setSaving(true)
    await run(SET_PRINTER_TAKES_JOBS, { printerId: printer.id, takesJobs }, 'setPrinterTakesJobs',
      { failure: 'Takes Jobs could not be saved' })
    setSaving(false)
  }

  return (
    <section aria-labelledby={id} className={classes.takesJobs}>
      <div className={classes.takesJobsText}>
        <h2 id={id} className={classes.takesJobsTitle}>Takes Jobs</h2>
        <span className={classes.small}>
          When off, the queue skips this printer: nothing new starts on it. A print under way goes on.
        </span>
      </div>
      <Switch aria-label="Takes jobs" checked={printer.takesJobs} loading={saving} onChange={change} />
    </section>
  )
}

// The file, its same-printer mark, and for a batch its size and the copies left to start ("× 10 · 4 left to start")
function JobFile ({ job }) {
  const batch = batchView(job)
  return (
    <div className={classes.queueCell}>
      <div className={classes.queueLine}>
        <FileName file={job.file} />
        {job.samePrinter && <Tag variant="filled" color="purple" style={{ marginInlineEnd: 0 }}>Same printer</Tag>}
      </div>
      {batch && <Muted small>{`${batch.size} · ${batch.left}`}</Muted>}
    </div>
  )
}

// Its place among the waiting jobs: the queue page's "#"
const positionColumn = (jobOf) => ({
  key: 'position',
  title: '#',
  width: 56,
  render: (_, row) => <Muted>{jobOf(row).waitingPosition}</Muted>
})

// The waiting jobs this printer can take, in queue order (held ones too, with Release). What Happens Next is said
// from this printer's page ("Starts once the bed is cleared") for the jobs lined up for it.
function UpNext ({ jobs, printerId, onRelease }) {
  const columns = [
    positionColumn((job) => job),
    { key: 'file', title: 'File', render: (_, job) => <JobFile job={job} /> },
    { key: 'needs', title: 'Needs', width: 200, render: (_, job) => <Needs needs={job.needs} /> },
    {
      key: 'next',
      title: 'What Happens Next',
      width: 280,
      render: (_, job) => <WhatHappensNextCell job={job} printerId={printerId} onRelease={onRelease} />
    }
  ]

  return (
    <QueueSection title="Up Next for This Printer" count={jobs.length}>
      <Table rowKey="id" columns={columns} dataSource={jobs} pagination={false} size="middle" tableLayout="fixed"
        scroll={{ x: 720 }} locale={{ emptyText: 'No waiting job for this printer' }} />
    </QueueSection>
  )
}

// The waiting jobs this printer can't take, each with the server's reasons, one per line
function Skipped ({ rows }) {
  const columns = [
    positionColumn(({ printJob }) => printJob),
    { key: 'file', title: 'File', render: (_, { printJob }) => <JobFile job={printJob} /> },
    {
      key: 'why',
      title: 'Why',
      width: 360,
      render: (_, { reasons }) => (
        <div className={classes.queueCell}>
          {reasons.map((reason, index) => <span key={index}>{reason}</span>)}
        </div>
      )
    }
  ]

  return (
    <QueueSection title="Skipped by This Printer" count={rows.length}>
      <Table rowKey={({ printJob }) => printJob.id} columns={columns} dataSource={rows} pagination={false}
        size="middle" tableLayout="fixed" scroll={{ x: 720 }} />
    </QueueSection>
  )
}

// The printer page's part of the global queue (shown only while it is on): the print to clear off the bed, Takes
// Jobs, Up Next and Skipped. Every action reloads the page's queue query (`reload`). It sits in the page's form: its
// buttons and switch are type="button" (antd's default), so none submits it.
export default function PrinterQueue ({ printer, dispatchPaused, reload }) {
  const actions = useQueueActions(reload)
  const bedCleared = useBedCleared({ dispatchPaused, onDone: reload })
  const askBedCleared = (filename) => bedCleared.ask(
    { id: printer.id, name: printer.name, takesJobs: printer.takesJobs }, filename
  )

  return (
    <div className={classes.queue}>
      {printer.bedNeedsClearing && <BedBanner printer={printer} onBedCleared={askBedCleared} />}
      <TakesJobs printer={printer} reload={reload} />
      <UpNext jobs={printer.upNext} printerId={printer.id} onRelease={actions.release} />
      {printer.skipped.length > 0 && <Skipped rows={printer.skipped} />}
      {bedCleared.modal}
    </div>
  )
}

const fileShape = PropTypes.shape({ id: PropTypes.string.isRequired, filename: PropTypes.string.isRequired })
const jobShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  waitingPosition: PropTypes.number,
  copies: PropTypes.number.isRequired,
  copiesLeftToStart: PropTypes.number.isRequired,
  samePrinter: PropTypes.bool,
  file: fileShape.isRequired
})
const skippedShape = PropTypes.shape({
  printJob: jobShape.isRequired,
  reasons: PropTypes.arrayOf(PropTypes.string).isRequired
})
const printerShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  name: PropTypes.string.isRequired,
  takesJobs: PropTypes.bool.isRequired,
  bedNeedsClearing: PropTypes.bool.isRequired,
  printOnBed: PropTypes.shape({ printJob: PropTypes.shape({ file: fileShape.isRequired }) }),
  upNext: PropTypes.arrayOf(jobShape).isRequired,
  skipped: PropTypes.arrayOf(skippedShape).isRequired
})

BedBanner.propTypes = { printer: printerShape.isRequired, onBedCleared: PropTypes.func.isRequired }
TakesJobs.propTypes = { printer: printerShape.isRequired, reload: PropTypes.func.isRequired }
JobFile.propTypes = { job: jobShape.isRequired }
UpNext.propTypes = {
  jobs: PropTypes.arrayOf(jobShape).isRequired,
  printerId: PropTypes.string.isRequired,
  onRelease: PropTypes.func.isRequired
}
Skipped.propTypes = { rows: PropTypes.arrayOf(skippedShape).isRequired }
PrinterQueue.propTypes = {
  printer: printerShape.isRequired,
  dispatchPaused: PropTypes.bool.isRequired,
  reload: PropTypes.func.isRequired
}
