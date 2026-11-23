import React, { useId, useState } from 'react'
import PropTypes from 'prop-types'
import { Button, Switch, Table, Tag, theme } from 'antd'
import { LockOutlined } from '@ant-design/icons'

import { useBedCleared } from '../../Queue/BedCleared'
import { Muted, QueueSection } from '../../Queue/parts'
import useQueueActions, { useQueueMutation } from '../../Queue/useQueueActions'
import whatHappensNext from '../../Queue/whatHappensNext'
import { SET_PRINTER_TAKES_JOBS } from './graphql/printerQueue'
import { bedBannerView, jobSizeText, needsLines, skippedSummary, takesJobsText } from './printerQueueView'
import * as classes from './PrinterDetails.module.less'

// The printer page's part of the global queue (the PrinterQueue frame), shown only while the queue is on. The page
// places each part: the switch in its header, the bed banner under it, Up Next and Skipped in its main column. Every
// action reloads the page's queue query (`reload`). They sit in the page's form: their buttons and switch are
// type="button" (antd's default), so none submits it.

// "Taking jobs from the queue": saved at once, apart from the page's form. A refusal shows as a message
// (useQueueMutation); the switch shows what the server has.
export function TakesJobsSwitch ({ printer, reload }) {
  const run = useQueueMutation(reload)
  const [saving, setSaving] = useState(false)

  const change = async (takesJobs) => {
    setSaving(true)
    await run(SET_PRINTER_TAKES_JOBS, { printerId: printer.id, takesJobs }, 'setPrinterTakesJobs',
      { failure: 'Taking jobs could not be saved' })
    setSaving(false)
  }

  // The label around the switch names it, and a click on its words flips it
  return (
    <label className={classes.takesJobs}>
      <Switch checked={printer.takesJobs} loading={saving} onChange={change} />
      <span>{takesJobsText(printer.takesJobs)}</span>
    </label>
  )
}

// The print still on the bed, and Bed Cleared (the queue page's modal and wording, with what the printer takes next):
// the printer takes nothing from the queue until then. The modal clears the print the banner names (printOnBed).
// Tinted with the theme's primary colours: it asks for an action, it doesn't warn.
export function BedBanner ({ printer, dispatchPaused, reload }) {
  const id = useId()
  const { token } = theme.useToken()
  const bedCleared = useBedCleared({ dispatchPaused, onDone: reload })
  const { title, text } = bedBannerView(printer.printOnBed)
  const ask = () => bedCleared.ask({
    id: printer.id, name: printer.name, takesJobs: printer.takesJobs, takesNext: printer.takesNext,
    printOnBed: printer.printOnBed
  })

  return (
    <section aria-labelledby={id} className={classes.bedBanner}
      style={{ background: token.colorPrimaryBg, borderColor: token.colorPrimaryBorder }}>
      <div className={classes.bedText}>
        <h2 id={id} className={classes.cardTitle}>{title}</h2>
        <Muted>{text}</Muted>
      </div>
      {/* Bed Cleared names the print it clears (expectedPrintId): none to name, nothing to confirm */}
      {printer.printOnBed && <Button type="primary" onClick={ask}>Bed Cleared</Button>}
      {bedCleared.modal}
    </section>
  )
}

// Its place among the waiting jobs: the queue page's "#"
const positionColumn = (jobOf) => ({
  key: 'position',
  width: 72,
  render: (_, row) => <span className={classes.position}><Muted>{`#${jobOf(row).waitingPosition}`}</Muted></span>
})

// The file in bold, its same-printer mark, then its batch size and copies left to start ("Batch of 10 · 7 left to
// start") or "1 print"
function JobFile ({ job }) {
  return (
    <div className={classes.queueCell}>
      <span className={classes.queueLine}>
        <span className={`${classes.strong} ${classes.ellipsis}`} title={job.file.filename}>{job.file.filename}</span>
        {job.samePrinter && <Tag icon={<LockOutlined />} className={classes.tag}>Same printer</Tag>}
      </span>
      <Muted small>{jobSizeText(job)}</Muted>
    </div>
  )
}

// What happens next, said from this printer's page ("Starts once the bed is cleared"); a held job's in secondary
// text, with Release
function NextCell ({ job, printerId, onRelease }) {
  const words = whatHappensNext(job, { printerId })
  if (!words) return null
  if (words.icon !== 'held') return <span>{words.text}</span>
  return (
    <span className={classes.queueLine}>
      <Muted>{words.text}</Muted>
      <Button size="small" onClick={() => onRelease(job)}>Release</Button>
    </span>
  )
}

// The waiting jobs this printer qualifies for, in queue order (held ones too, with Release). The one it takes next
// (Printer.takesNext) is highlighted.
export function UpNext ({ printer, reload }) {
  const { token } = theme.useToken()
  const actions = useQueueActions(reload)
  const columns = [
    positionColumn((job) => job),
    { key: 'file', render: (_, job) => <JobFile job={job} /> },
    {
      key: 'needs',
      width: '22%',
      render: (_, job) => (
        <div className={classes.queueCell}>{needsLines(job.needs).map((line, index) => <span key={index}>{line}</span>)}</div>
      )
    },
    {
      key: 'next',
      width: '34%',
      render: (_, job) => <NextCell job={job} printerId={printer.id} onRelease={actions.release} />
    }
  ]
  const takesNext = (job) => job.id === printer.takesNext?.id

  return (
    <QueueSection title="Up Next for This Printer" extra={<Muted>In queue order, jobs it qualifies for</Muted>}>
      <Table rowKey="id" columns={columns} dataSource={printer.upNext} pagination={false} showHeader={false}
        size="middle" tableLayout="fixed" scroll={{ x: 560 }} locale={{ emptyText: 'No waiting job for this printer' }}
        onRow={(job) => (takesNext(job) ? { style: { background: token.colorPrimaryBg } } : {})} />
    </QueueSection>
  )
}

// The waiting jobs this printer can't take, each with the server's reasons, one per line. Nothing when it skips none.
export function Skipped ({ rows }) {
  if (rows.length === 0) return null
  const columns = [
    positionColumn(({ printJob }) => printJob),
    {
      key: 'file',
      width: '36%',
      render: (_, { printJob }) => (
        <span className={classes.ellipsis} title={printJob.file.filename}>{printJob.file.filename}</span>
      )
    },
    {
      key: 'why',
      render: (_, { reasons }) => (
        <div className={classes.queueCell}>{reasons.map((reason, index) => <Muted key={index}>{reason}</Muted>)}</div>
      )
    }
  ]

  return (
    <QueueSection title="Skipped by This Printer" extra={<Muted>{skippedSummary(rows.length)}</Muted>}>
      <Table rowKey={({ printJob }) => printJob.id} columns={columns} dataSource={rows} pagination={false}
        showHeader={false} size="middle" tableLayout="fixed" scroll={{ x: 560 }} />
    </QueueSection>
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
  bedNeedsClearing: PropTypes.bool,
  printOnBed: PropTypes.shape({
    id: PropTypes.string.isRequired,
    copyNumber: PropTypes.number,
    result: PropTypes.string,
    printJob: PropTypes.shape({ copies: PropTypes.number, file: fileShape.isRequired })
  }),
  takesNext: PropTypes.shape({ id: PropTypes.string.isRequired }),
  upNext: PropTypes.arrayOf(jobShape),
  skipped: PropTypes.arrayOf(skippedShape)
})

TakesJobsSwitch.propTypes = { printer: printerShape.isRequired, reload: PropTypes.func.isRequired }
BedBanner.propTypes = {
  printer: printerShape.isRequired,
  dispatchPaused: PropTypes.bool.isRequired,
  reload: PropTypes.func.isRequired
}
JobFile.propTypes = { job: jobShape.isRequired }
NextCell.propTypes = { job: jobShape.isRequired, printerId: PropTypes.string.isRequired, onRelease: PropTypes.func.isRequired }
UpNext.propTypes = { printer: printerShape.isRequired, reload: PropTypes.func.isRequired }
Skipped.propTypes = { rows: PropTypes.arrayOf(skippedShape).isRequired }
