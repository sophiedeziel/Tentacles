import React from 'react'
import PropTypes from 'prop-types'

import queueView from './queueView'
import { EmptyQueue, Header, NextRow, NowItem, ReadyBar, plainStartNext } from './parts'
import * as classes from './PrintQueueWidget.module.less'

// Small: only the number of queued jobs, large (grey when there are none)
function SmallLayout ({ view }) {
  return (
    <div className={classes.small}>
      <Header title={view.smallTitle} />
      <div className={classes.smallCount}>
        <strong style={{ color: view.count ? '#722ed1' : 'rgba(0, 0, 0, 0.45)' }}>{view.count}</strong>
        <span>{view.countLabel}</span>
      </div>
    </div>
  )
}

// Medium: what prints now, then the next jobs with their position
function MediumLayout ({ view }) {
  return (
    <div className={classes.column} style={{ gap: 4 }}>
      <Header title={view.title} right={view.queuedLabel} />
      {view.empty && <EmptyQueue />}
      <div className={classes.rows}>
        {view.rows.map((row) => (row.isNow
          ? (
            <div key={`now-${row.printerId}`} className={classes.tallRow}>
              <span className={classes.nowDot} style={{ background: row.tint }}><span style={{ background: row.color }} /></span>
              <span className={classes.file} title={row.file}>{row.file}</span>
              <span className={classes.side}>{row.side}</span>
            </div>
            )
          : <NextRow key={row.id} row={row} tall />))}
      </div>
    </div>
  )
}

// Large: the printing jobs with their progress, the next jobs, and a Start Next bar when a printer is ready
function LargeLayout ({ view, renderStartNext }) {
  return (
    <div className={classes.column}>
      <Header title={view.title} right={view.queuedLabel} />
      {view.empty && <EmptyQueue illustration />}
      <UpNextColumn view={view} renderStartNext={renderStartNext} />
    </div>
  )
}

// Printing, Up next, "+ N more" and the ready bar: Large, and the left column of the Extra Large lists
export function UpNextColumn ({ view, renderStartNext }) {
  return (
    <>
      {view.now.length > 0 && (
        <>
          <span className={classes.label}>Printing</span>
          {view.now.map((item) => <NowItem key={item.printerId} item={item} />)}
        </>
      )}
      {view.next.length > 0 && (
        <>
          <span className={classes.label} style={{ marginTop: 2 }}>Up next</span>
          <div className={classes.rows}>
            {view.next.map((row) => <NextRow key={row.id} row={row} />)}
          </div>
          {view.moreText && <span className={classes.more}>{view.moreText}</span>}
        </>
      )}
      {view.ready && <ReadyBar ready={view.ready} renderStartNext={renderStartNext} />}
    </>
  )
}

const LAYOUTS = { S: SmallLayout, M: MediumLayout, L: LargeLayout }

// What prints next, for all printers or one. Presentational: it renders from props only, so the Add Widget gallery
// can show it with fixture data.
// - printers: the dashboard's printers ({ id name status canStartNext queuedCount nextJob })
// - printerId: the printer it follows, null for all printers
// - size: 'S' to 'XXL'; options: the widget's options; now: the dashboard's clock
// - queue: printQueue's { totalCount, jobs }, history: jobHistory's jobs (null until loaded, or not needed)
// - renderStartNext(printer): the Start Next button of a ready printer; a plain button by default
export default function PrintQueueWidget ({
  printers, printerId = null, size, options, queue = null, history = null, now, renderStartNext = plainStartNext
}) {
  const Layout = LAYOUTS[size]
  if (!Layout) return null // Extra Large and up come next

  const view = queueView({ printers, printerId, size, options, queue, history, now })
  return <Layout view={view} renderStartNext={renderStartNext} />
}

PrintQueueWidget.propTypes = {
  printers: PropTypes.arrayOf(PropTypes.shape({
    id: PropTypes.string.isRequired,
    name: PropTypes.string.isRequired,
    status: PropTypes.object.isRequired,
    canStartNext: PropTypes.bool,
    queuedCount: PropTypes.number,
    nextJob: PropTypes.object
  })).isRequired,
  printerId: PropTypes.string,
  size: PropTypes.oneOf(['S', 'M', 'L', 'XL', 'XXL']).isRequired,
  options: PropTypes.shape({
    nowPrinting: PropTypes.bool,
    startNext: PropTypes.bool,
    rowPerPrinter: PropTypes.bool,
    history: PropTypes.bool
  }).isRequired,
  queue: PropTypes.shape({ totalCount: PropTypes.number.isRequired, jobs: PropTypes.array.isRequired }),
  history: PropTypes.array,
  now: PropTypes.oneOfType([PropTypes.instanceOf(Date), PropTypes.number]).isRequired,
  renderStartNext: PropTypes.func
}

const layoutPropTypes = { view: PropTypes.object.isRequired, renderStartNext: PropTypes.func }
SmallLayout.propTypes = layoutPropTypes
MediumLayout.propTypes = layoutPropTypes
LargeLayout.propTypes = layoutPropTypes
UpNextColumn.propTypes = layoutPropTypes
