import React from 'react'
import PropTypes from 'prop-types'
import { Button, Progress, theme } from 'antd'
import { Link } from 'react-router'

import EmptyState from '../../../../components/EmptyState/EmptyState'
import { PrintQueueOutlined } from '../../../../components/icons'
import * as classes from './PrintQueueWidget.module.less'

// The widget's title line: the queue icon, the title and, on the right, how many jobs wait
export function Header ({ title, right }) {
  return (
    <div className={classes.header}>
      <PrintQueueOutlined />
      <span className={classes.title} title={title}>{title}</span>
      {right && <span className={classes.nowrap}>{right}</span>}
    </div>
  )
}

// One job of the queue: its position, its file and (for all printers) its printer
export function NextRow ({ row, tall = false }) {
  return (
    <div className={tall ? classes.tallRow : classes.row}>
      <span className={classes.position}>{row.pos}</span>
      <span className={classes.file} title={row.file}>{row.file}</span>
      {row.printer && <span className={classes.side}>{row.printer}</span>}
    </div>
  )
}

// A job under way: its file, its printer and time left (all printers) and its progress, from the live status.
// One printer shows the time left on its own line.
export function NowItem ({ item }) {
  return (
    <div className={classes.nowItem}>
      <div className={classes.nowLine}>
        <span className={classes.file} title={item.file}>{item.file}</span>
        {item.printer && <span className={classes.side}>{item.printer}</span>}
      </div>
      <Progress percent={item.progress} strokeColor={item.color} size="small" />
      {item.showMeta && <span className={classes.meta}>{item.meta}</span>}
    </div>
  )
}

// "Prusa Mini+ is ready for spool_holder.gcode", with its Start Next button
export function ReadyBar ({ ready, renderStartNext }) {
  return (
    <div className={classes.readyBar}>
      <span className={classes.readyLabel} title={ready.label}>{ready.label}</span>
      {renderStartNext(ready.printer)}
    </div>
  )
}

// Start Next without a confirmation, for previews: the dashboard passes its confirmed control instead
export function plainStartNext () {
  return <Button size="small">Start Next</Button>
}

// Where prints are enqueued. The link takes the theme's primary colour, like antd's links.
export function SendFromFiles () {
  const { token } = theme.useToken()
  return <>Send G-code from <Link to="/files" style={{ color: token.colorPrimary }}>Files</Link> to start a print.</>
}

// The empty queue: text only at Medium, the shared empty state with its illustration from Large up. Both point to
// Files, where prints are enqueued.
export function EmptyQueue ({ illustration = false }) {
  if (!illustration) {
    return (
      <div className={classes.emptyText}>
        <strong>Queue is empty</strong>
        <span><SendFromFiles /></span>
      </div>
    )
  }
  return (
    <div className={classes.emptyIllustration}>
      <EmptyState kind="queue" title="Queue is empty" description={<SendFromFiles />} />
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

Header.propTypes = { title: PropTypes.string.isRequired, right: PropTypes.string }
NextRow.propTypes = { row: PropTypes.object.isRequired, tall: PropTypes.bool }
NowItem.propTypes = { item: PropTypes.object.isRequired }
ReadyBar.propTypes = { ready: PropTypes.object.isRequired, renderStartNext: PropTypes.func.isRequired }
EmptyQueue.propTypes = { illustration: PropTypes.bool }
UpNextColumn.propTypes = { view: PropTypes.object.isRequired, renderStartNext: PropTypes.func.isRequired }
