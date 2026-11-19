import React from 'react'
import PropTypes from 'prop-types'

import JobStatus from '../../../../components/JobStatus/JobStatus'
import PrinterStatus from '../../../../components/PrinterStatus/PrinterStatus'
import { EmptyQueue, Header, NextRow, SendFromFiles, UpNextColumn } from './parts'
import * as classes from './PrintQueueWidget.module.less'

function HistoryRow ({ row, tall = false }) {
  return (
    <div className={tall ? classes.tallRow : classes.row}>
      <span className={classes.file} title={row.file}>{row.file}</span>
      <span className={classes.side}>{row.side}</span>
      <JobStatus status={row.status} />
    </div>
  )
}

// One printer of the table: its state, what it prints now, its next job, how many wait, and Start Next when ready
function PrinterRow ({ row, renderStartNext }) {
  const { printer, current } = row
  return (
    <div role="row" className={classes.tableRow}>
      <div role="cell" className={classes.cell}>
        <PrinterStatus family={printer.status.stateFamily} text={printer.status.stateText} variant="icon" />
        <span className={classes.printerName} title={printer.name}>{printer.name}</span>
      </div>
      <div role="cell" className={classes.nowCell}>
        {current
          ? (
            <>
              <div className={classes.cell}>
                <span className={classes.file} title={current.file}>{current.file}</span>
                <span className={classes.side}>{current.short}</span>
              </div>
              <div className={classes.bar}><span style={{ width: `${current.progress}%`, background: current.color }} /></div>
            </>
            )
          : <span className={classes.side}>{row.nowText}</span>}
      </div>
      <span role="cell" className={classes.small12} style={{ color: row.count ? undefined : 'rgba(0, 0, 0, 0.65)' }}>
        {row.nextFile}
      </span>
      <span role="cell" className={classes.count} style={{ color: row.count ? undefined : 'rgba(0, 0, 0, 0.65)' }}>
        {row.count}
      </span>
      <div role="cell" className={classes.end}>{row.canStart && renderStartNext(printer)}</div>
    </div>
  )
}

// All printers with one row per printer: the table, folded past what fits, and at 4×4 the shared up next list and
// history underneath
function TableLayout ({ view, renderStartNext }) {
  return (
    <>
      <div role="table" aria-label="Queues by printer" className={classes.table}>
        <div role="row" className={classes.tableHead}>
          <span role="columnheader">Printer</span>
          <span role="columnheader">Now</span>
          <span role="columnheader">Up next</span>
          <span role="columnheader" style={{ textAlign: 'right' }}>Queued</span>
          <span role="columnheader" />
        </div>
        {view.shown.map((row) => <PrinterRow key={row.printer.id} row={row} renderStartNext={renderStartNext} />)}
        {view.moreText && <div className={classes.foldLine}>{view.moreText}</div>}
      </div>
      {view.under && (
        <div className={classes.under}>
          <div className={classes.listColumn} style={{ gap: 4 }}>
            <span className={classes.label}>Up next, all printers</span>
            {view.under.next.map((row) => <NextRow key={row.id} row={row} />)}
          </div>
          {view.under.showHistory && (
            <div className={classes.listColumn} style={{ gap: 4 }}>
              <span className={classes.label}>History</span>
              {view.under.history.map((row) => <HistoryRow key={row.id} row={row} />)}
            </div>
          )}
        </div>
      )}
    </>
  )
}

// One queue for all printers, or one printer's: up next on the left, history on the right
function ListLayout ({ view, renderStartNext }) {
  return (
    <div className={classes.columns}>
      <div className={classes.listColumn}>
        {view.empty
          ? (
            <>
              <span className={classes.label}>Up next</span>
              <span>Nothing queued</span>
              <span className={classes.more}><SendFromFiles /></span>
            </>
            )
          : <UpNextColumn view={view} renderStartNext={renderStartNext} />}
      </div>
      {view.showHistory && (
        <div className={classes.historyColumn}>
          <span className={classes.label}>History</span>
          <div className={classes.rows}>
            {view.history.map((row) => <HistoryRow key={row.id} row={row} tall />)}
          </div>
          {view.history.length === 0 && <span className={classes.more}>Nothing printed yet.</span>}
        </div>
      )}
    </div>
  )
}

// Extra Large (4×2) and Extra Extra Large (4×4)
export default function BigLayout ({ view, renderStartNext }) {
  let body
  if (view.table) body = <TableLayout view={view} renderStartNext={renderStartNext} />
  else if (view.list) body = <ListLayout view={view} renderStartNext={renderStartNext} />
  else body = <EmptyQueue illustration />

  return (
    <div className={classes.big}>
      <Header title={view.title} right={view.queuedLabel} />
      {body}
    </div>
  )
}

const layoutPropTypes = { view: PropTypes.object.isRequired, renderStartNext: PropTypes.func.isRequired }
BigLayout.propTypes = layoutPropTypes
TableLayout.propTypes = layoutPropTypes
ListLayout.propTypes = layoutPropTypes
PrinterRow.propTypes = { row: PropTypes.object.isRequired, renderStartNext: PropTypes.func.isRequired }
HistoryRow.propTypes = { row: PropTypes.object.isRequired, tall: PropTypes.bool }
