import React from 'react'
import PropTypes from 'prop-types'
import { Table, Tooltip, Typography } from 'antd'

import JobStatus from '../../components/JobStatus/JobStatus'
import PrinterStatus from '../../components/PrinterStatus/PrinterStatus'
import PrintProgress from '../../components/PrintProgress/PrintProgress'
import { doneAt, formatDayClock } from '../../utils/time'
import { FilamentLine, Muted, QueueLink, QueueSection, TwoLines } from './parts'
import { copyText, printLabel, printingSummary } from './queueView'
import * as classes from './QueuePage.module.less'

// The state families a print is under way in: the printer's status says how far it got
const UNDER_WAY = ['PRINTING', 'PAUSED', 'CANCELLING']

const statusOf = (printer) => printer.status || { stateFamily: 'OFFLINE', stateText: 'Offline' }

// Live from the printer's status (printerStatusChanged): the progress bar and time left while under way. A copy
// handed to a printer that hasn't started it yet reads as Starting.
function PrintingProgress ({ print, now }) {
  const status = statusOf(print.printer)
  const family = status.stateFamily
  if (!UNDER_WAY.includes(family)) return <Muted>{print.status === 'ENQUEUED' ? 'Starting' : 'Waiting for the printer'}</Muted>

  const finish = family === 'PRINTING' ? doneAt(status.updatedAt, status.printTimeLeft) : null
  return <PrintProgress family={family} progress={status.progress ?? print.progress}
    timeLeft={finish ? finish.diff(now) : null} />
}

// The printer (a link to its page) and the filament it has loaded
function PrintingPrinter ({ printer }) {
  const filaments = printer.loadedFilaments || []
  return (
    <div className={classes.cell}>
      <QueueLink to={`/printers/${printer.id}`}>{printer.name}</QueueLink>
      {filaments.map((filament) => <FilamentLine key={filament.slot} filament={filament} small />)}
    </div>
  )
}

// The copies under way, in the order they were handed out. `renderMenu(print)`: a row's "⋯" menu.
export function Printing ({ prints, now, renderMenu }) {
  const rows = prints.map((print) => ({ key: print.id, print }))
  const columns = [
    {
      key: 'file',
      title: 'File',
      render: (_, { print }) => <TwoLines strong title={print.printJob.file.filename} detail={copyText(print) || '1 print'} />
    },
    { key: 'printer', title: 'Printer', width: '24%', render: (_, { print }) => <PrintingPrinter printer={print.printer} /> },
    {
      key: 'state',
      title: 'State',
      width: 150,
      render: (_, { print }) => {
        const status = statusOf(print.printer)
        return <PrinterStatus family={status.stateFamily} text={status.stateText} />
      }
    },
    { key: 'progress', title: 'Progress', width: '30%', render: (_, { print }) => <PrintingProgress print={print} now={now} /> },
    { key: 'actions', width: 56, align: 'right', render: (_, { print }) => renderMenu?.(print) }
  ]

  return (
    <QueueSection title="Printing" summary={printingSummary(prints)}>
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
        scroll={{ x: 860 }} locale={{ emptyText: 'Nothing is printing' }} />
    </QueueSection>
  )
}

// All History opens the print history, which comes with its own page later
function AllHistory () {
  return (
    <Tooltip title="Coming soon">
      <span><Typography.Link disabled>All History</Typography.Link></span>
    </Tooltip>
  )
}

// The latest copies that ended, the last one first, with how they ended. `renderAction(print)`: Requeue, from the
// page's actions.
export function Finished ({ prints, now, renderAction }) {
  const rows = prints.map((print) => ({ key: print.id, print }))
  const columns = [
    {
      key: 'file',
      render: (_, { print }) => <span className={classes.ellipsis} title={printLabel(print)}>{printLabel(print)}</span>
    },
    {
      key: 'result',
      width: 150,
      render: (_, { print }) => print.result && <JobStatus status={print.result.toLowerCase()} />
    },
    { key: 'printer', width: '22%', render: (_, { print }) => print.printer.name },
    {
      key: 'finishedAt',
      width: '20%',
      render: (_, { print }) => print.finishedAt && <Muted>{formatDayClock(print.finishedAt, now)}</Muted>
    },
    { key: 'action', width: 120, align: 'right', render: (_, { print }) => renderAction?.(print) }
  ]

  return (
    <QueueSection title="Finished" extra={<AllHistory />}>
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
        showHeader={false} scroll={{ x: 760 }} locale={{ emptyText: 'No print has finished yet' }} />
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

PrintingProgress.propTypes = { print: printShape.isRequired, now: PropTypes.number.isRequired }
PrintingPrinter.propTypes = { printer: PropTypes.object.isRequired }
Printing.propTypes = {
  prints: PropTypes.arrayOf(printShape).isRequired,
  now: PropTypes.number.isRequired,
  renderMenu: PropTypes.func
}
Finished.propTypes = {
  prints: PropTypes.arrayOf(printShape).isRequired,
  now: PropTypes.number.isRequired,
  renderAction: PropTypes.func
}
