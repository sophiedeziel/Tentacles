import React from 'react'
import PropTypes from 'prop-types'
import { Table } from 'antd'

import JobStatus from '../../components/JobStatus/JobStatus'
import PrinterStatus from '../../components/PrinterStatus/PrinterStatus'
import PrintProgress from '../../components/PrintProgress/PrintProgress'
import { doneAt, formatAgo } from '../../utils/time'
import { FileName, Muted, PrinterCell, QueueSection } from './parts'
import { copyText } from './queueView'
import * as classes from './QueuePage.module.less'

// The state families a print is under way in: the printer's status says how far it got
const UNDER_WAY = ['PRINTING', 'PAUSED', 'CANCELLING']

// A print's file, and which copy of its batch it is
function PrintFile ({ print }) {
  const copy = copyText(print)
  return (
    <div className={classes.cell}>
      <FileName file={print.printJob.file} />
      {copy && <Muted small>{copy}</Muted>}
    </div>
  )
}

// Live from the printer's status (printerStatusChanged): the progress bar and time left while under way. A copy
// handed to a printer that hasn't started it yet reads as Starting.
function PrintingProgress ({ print, now }) {
  const status = print.printer.status || { stateFamily: 'OFFLINE' }
  const family = status.stateFamily
  if (!UNDER_WAY.includes(family)) return <Muted>{print.status === 'ENQUEUED' ? 'Starting' : 'Waiting for the printer'}</Muted>

  const finish = family === 'PRINTING' ? doneAt(status.updatedAt, status.printTimeLeft) : null
  return <PrintProgress family={family} progress={status.progress ?? print.progress}
    timeLeft={finish ? finish.diff(now) : null} />
}

// The copies under way, in the order they were handed out
export function Printing ({ prints, now }) {
  const rows = prints.map((print) => ({ key: print.id, print }))
  const columns = [
    { key: 'file', title: 'File', render: (_, { print }) => <PrintFile print={print} /> },
    {
      key: 'printer',
      title: 'Printer',
      width: 280,
      render: (_, { print }) => {
        const status = print.printer.status || { stateFamily: 'OFFLINE', stateText: 'Offline' }
        return <PrinterCell printer={print.printer}
          subtitle={<PrinterStatus family={status.stateFamily} text={status.stateText} variant="badge" />} />
      }
    },
    { key: 'progress', title: 'Progress', width: 260, render: (_, { print }) => <PrintingProgress print={print} now={now} /> }
  ]

  return (
    <QueueSection title="Printing" count={prints.length}>
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
        locale={{ emptyText: 'Nothing is printing' }} />
    </QueueSection>
  )
}

// The latest copies that ended, the last one first, with how they ended. The full history comes with its own page.
export function Finished ({ prints, now }) {
  const rows = prints.map((print) => ({ key: print.id, print }))
  const columns = [
    { key: 'file', title: 'File', render: (_, { print }) => <PrintFile print={print} /> },
    { key: 'printer', title: 'Printer', width: 280, render: (_, { print }) => <PrinterCell printer={print.printer} /> },
    {
      key: 'result',
      title: 'Result',
      width: 140,
      render: (_, { print }) => print.result && <JobStatus status={print.result.toLowerCase()} />
    },
    {
      key: 'finishedAt',
      title: 'Finished',
      width: 120,
      render: (_, { print }) => print.finishedAt && <Muted>{formatAgo(print.finishedAt, now)}</Muted>
    }
  ]

  return (
    <QueueSection title="Finished">
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
        locale={{ emptyText: 'No print has finished yet' }} />
    </QueueSection>
  )
}

const printShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  status: PropTypes.string.isRequired,
  progress: PropTypes.number,
  printer: PropTypes.object.isRequired,
  printJob: PropTypes.object.isRequired
})

PrintFile.propTypes = { print: printShape.isRequired }
PrintingProgress.propTypes = { print: printShape.isRequired, now: PropTypes.number.isRequired }
Printing.propTypes = { prints: PropTypes.arrayOf(printShape).isRequired, now: PropTypes.number.isRequired }
Finished.propTypes = { prints: PropTypes.arrayOf(printShape).isRequired, now: PropTypes.number.isRequired }
