import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import PropTypes from 'prop-types'
import { Link } from 'react-router'
import { Button, Dropdown, Segmented, Table, Tag, Typography, theme } from 'antd'
import {
  CheckOutlined, ClockCircleOutlined, DownOutlined, LockOutlined, PauseOutlined, RightOutlined, WarningOutlined
} from '@ant-design/icons'

import JobStatus from '../../components/JobStatus/JobStatus'
import { doneAt, formatDayClock, formatTimeLeft } from '../../utils/time'
import { FilamentDot, Muted, QueueLink, QueueSection, TwoLines } from './parts'
import { batchSummary, batchView, needsView, printersView, waitingCopiesView, waitingSummary } from './queueView'
import whatHappensNext, { WAITING_FILTERS, matchesFilter } from './whatHappensNext'
import { WaitingMenu, actionsShape } from './menus'
import SortableRows, { DragHandle, SortableRow } from './SortableRows'
import * as classes from './QueuePage.module.less'

// Load Filament opens the page of a printer that could print the job once its filament is changed, where Loaded
// Filament is set: a link for one printer, a menu of them for more
function LoadFilament ({ printers }) {
  const { token } = theme.useToken()
  if (printers.length === 1) return <QueueLink to={`/printers/${printers[0].id}`}>Load Filament</QueueLink>

  const items = printers.map((printer) => ({
    key: printer.id,
    label: <Link to={`/printers/${printer.id}`}>{printer.name}</Link>
  }))
  return (
    <Dropdown menu={{ items }} trigger={['click']}>
      <Button type="link" size="small" className={classes.inlineLink} style={{ color: token.colorPrimary }}>
        Load Filament <DownOutlined />
      </Button>
    </Dropdown>
  )
}

// What Happens Next's mark: a check when a printer takes it as soon as it is free, a clock while it waits on
// something, a warning when blocked, a pause mark when held. Colours from the theme.
function NextIcon ({ icon }) {
  const { token } = theme.useToken()
  if (icon === 'next') return <CheckOutlined aria-hidden style={{ color: token.colorSuccess }} />
  if (icon === 'blocked') return <WarningOutlined aria-hidden style={{ color: token.colorWarning }} />
  if (icon === 'held') return <PauseOutlined aria-hidden style={{ color: token.colorTextSecondary }} />
  return <ClockCircleOutlined aria-hidden style={{ color: token.colorTextSecondary }} />
}

// What happens next to the job, in words (whatHappensNext.js), after its mark. A held job offers Release
// (`onRelease`), a blocked one Load Filament. `printerId`: the printer whose page it is on (the printer page's Up Next).
export function WhatHappensNextCell ({ job, printerId, onRelease }) {
  const words = whatHappensNext(job, { printerId })
  if (!words) return null

  return (
    <span className={classes.next}>
      <span className={classes.nextIcon}><NextIcon icon={words.icon} /></span>
      <span className={classes.nextText}>
        {words.text}
        {words.loadFilament && <> <LoadFilament printers={job.eligiblePrinters} /></>}
        {words.icon === 'held' && onRelease && (
          <Button size="small" className={classes.release} onClick={() => onRelease(job)}>Release</Button>
        )}
      </span>
    </span>
  )
}

// The file, its batch size ("× 10") and same-printer mark, then the copies left to start or "1 print"
function JobFile ({ job }) {
  const batch = batchView(job)

  return (
    <div className={classes.cell}>
      <span className={classes.fileLine}>
        <span className={`${classes.strong} ${classes.ellipsis}`} title={job.file.filename}>{job.file.filename}</span>
        {batch && (
          <Tag variant="filled" color="purple" className={classes.tag} aria-label={`${job.copies} copies`}>
            {batch.size}
          </Tag>
        )}
        {job.samePrinter && <Tag icon={<LockOutlined />} className={classes.tag}>Same printer</Tag>}
      </span>
      <Muted small>{batch ? batch.left : '1 print'}</Muted>
    </div>
  )
}

// Material and colour per tool (with its colour's dot), then the footprint (the printer page's Up Next too)
export function Needs ({ needs }) {
  const view = needsView(needs)
  if (view.pending) return <Muted>Reading the G-code</Muted>
  if (view.unknown) return <Muted>Not known</Muted>

  return (
    <div className={classes.cell}>
      {view.filaments.map((filament) => (
        <span key={filament.key} className={classes.filament}>
          <FilamentDot colour={filament.colour} />{filament.text}
        </span>
      ))}
      {view.footprint && <Muted small>{view.footprint}</Muted>}
      {view.filaments.length === 0 && !view.footprint && <Muted>Nothing known</Muted>}
    </div>
  )
}

// How far a copy got: when it ended, or its progress (live from its printer's status, when the copy is printing)
function copyDetail (print, live, now) {
  if (print.finishedAt) return formatDayClock(print.finishedAt, now)
  if (print.status === 'ENQUEUED') return 'Starting'
  const status = live?.printer.status
  const percent = Math.round(status?.progress ?? print.progress ?? 0)
  if (status?.stateFamily === 'PAUSED') return `Paused at ${percent}%`
  const finish = status?.stateFamily === 'PRINTING' ? doneAt(status.updatedAt, status.printTimeLeft) : null
  return finish ? `${percent}%, ${formatTimeLeft(finish.diff(now))} left` : `${percent}%`
}

const copyStatus = (print) => {
  if (print.status === 'ENQUEUED' || print.status === 'ACTIVE') return 'active'
  return (print.result || print.status).toLowerCase()
}

// A batch's copies, under its row: a summary ("2 done · 1 printing · 7 waiting"), a row per copy handed to a printer,
// then one row for the copies left to start. `live`: the Printing rows by print id (their printer's live status).
// `action`: on the summary's right (Release to Other Printers).
export function BatchCopies ({ job, live = {}, now, action }) {
  const waiting = waitingCopiesView(job)
  const rows = [
    ...[...job.prints].sort((a, b) => a.copyNumber - b.copyNumber).map((print) => ({
      key: print.id,
      label: `Copy ${print.copyNumber} of ${job.copies}`,
      status: copyStatus(print),
      printer: print.printer.name,
      detail: copyDetail(print, live[print.id], now)
    })),
    ...(job.copiesLeftToStart > 0
      ? [{ key: 'waiting', label: waiting.label, status: 'enqueued', printer: waiting.printer, detail: waiting.detail }]
      : [])
  ]
  const columns = [
    { key: 'label', dataIndex: 'label', width: 130 },
    { key: 'status', width: 150, render: (_, row) => <JobStatus status={row.status} /> },
    { key: 'printer', dataIndex: 'printer' },
    { key: 'detail', render: (_, row) => <Muted>{row.detail}</Muted> }
  ]

  return (
    <div className={classes.copies} aria-label={`Copies of ${job.file.filename}`} role="group">
      <div className={classes.copiesSummary}>
        <Typography.Text type="secondary" strong className={classes.small}>{batchSummary(job)}</Typography.Text>
        {action}
      </div>
      <Table columns={columns} dataSource={rows} pagination={false} size="small" tableLayout="fixed" showHeader={false}
        className={classes.copiesTable} />
    </div>
  )
}

// The chevron that shows a batch's copies
function ExpandButton ({ expanded, onExpand, record, expandable }) {
  if (!expandable) return null
  return (
    <button type="button" className={classes.expand} aria-expanded={expanded}
      aria-label={`Show the copies of ${record.job.file.filename}`} onClick={(event) => onExpand(record, event)}>
      <RightOutlined rotate={expanded ? 90 : 0} />
    </button>
  )
}

const EMPTY_TEXT = {
  All: 'Nothing is waiting',
  Ready: 'No job is ready for a printer',
  Blocked: 'No job is blocked',
  'On Hold': 'No job is on hold'
}

// Release to Other Printers, on an expanded batch bound to its printer: its waiting copies go to any printer again
function ReleaseToOthers ({ job, onUnbind }) {
  const [busy, setBusy] = useState(false)
  const release = async () => {
    setBusy(true)
    await onUnbind(job)
    setBusy(false)
  }
  return <Button size="small" loading={busy} onClick={release}>Release to Other Printers</Button>
}

// The Waiting table's body rows: sortable by their key (SortableRows)
const SORTABLE_BODY = { body: { row: SortableRow } }

// `jobs` in the order `ids` gives (a row moved ahead of the server), then any job `ids` doesn't know yet
export function inOrder (jobs, ids) {
  if (!ids) return jobs
  const byId = new Map(jobs.map((job) => [job.id, job]))
  const ordered = ids.map((id) => byId.get(id)).filter(Boolean)
  return [...ordered, ...jobs.filter((job) => !ids.includes(job.id))]
}

// The jobs with copies left to start, in queue order, filtered by what happens next to them (WAITING_FILTERS: the
// "#" stays each job's place in the whole queue). A batch is one row (it moves as one) and expands to its copies; a
// blocked one is tinted. Tagged Dispatch paused while no printer takes a job.
// `printing`: the Printing rows, for the progress of a batch's copies. `onCopies(job)`: the copies dialog.
// `reveal` ({ id, at }): show that job's row (Show Batch in Waiting): all jobs, its copies expanded, scrolled to.
//
// Drag a row by its handle (or with the keyboard from it) to reorder, with All shown: the row moves at once, then
// movePrintJob is sent; when it is refused the row goes back (useQueueActions shows why). `onDragChange(true)` while
// a row is dragged: the page holds its reloads (useGlobalQueue's `holding`) until the drop.
//
// Moves are sent one after the other (each drop's beforeId assumes the moves before it were made). The order shown
// while a move is on its way is cleared once its reload landed, unless a row is being dragged then: the rows under
// the pointer keep their places until that drop.
export function Waiting ({ jobs, paused, printing = [], now, actions, onCopies, reveal = null, onDragChange = () => {} }) {
  const { token } = theme.useToken()
  const [filter, setFilter] = useState('All')
  const [expanded, setExpanded] = useState([])
  // The order shown while a move is on its way: { ids, move, settled }. `move` is the last move it's for; `settled`
  // when that move's reload landed during a drag.
  const [moved, setMoved] = useState(null)
  // The row being dragged, null between drags
  const [dragged, setDragged] = useState(null)
  const draggingRef = useRef(false)
  const moves = useRef(Promise.resolve())
  const tableRef = useRef(null)
  const live = Object.fromEntries(printing.map((print) => [print.id, print]))
  const shown = inOrder(jobs, moved?.ids)
  const ids = useMemo(() => shown.map((job) => job.id), [shown])
  const names = useMemo(() => new Map(shown.map((job) => [job.id, job.file.filename])), [shown])
  const nameOf = useCallback((id) => names.get(id) || 'The row', [names])
  const sortable = filter === 'All'

  const show = useCallback((job) => {
    setFilter('All')
    if (job.copies > 1) setExpanded((keys) => (keys.includes(job.id) ? keys : [...keys, job.id]))
  }, [])

  // Show Batch in Waiting: the row, its copies expanded, scrolled to once drawn
  useEffect(() => {
    if (!reveal) return undefined
    show({ id: reveal.id, copies: 2 })
    const frame = requestAnimationFrame(() => {
      tableRef.current?.querySelector(`tr[data-row-key="${reveal.id}"]`)?.scrollIntoView?.({ behavior: 'smooth', block: 'center' })
    })
    return () => cancelAnimationFrame(frame)
  }, [reveal, show])

  const startDrag = ({ active }) => {
    draggingRef.current = true
    setDragged(active.id)
    onDragChange(true)
  }
  const settle = (move) => setMoved((current) => {
    if (current?.move !== move) return current
    return draggingRef.current ? { ...current, settled: true } : null
  })
  const drop = (move) => {
    draggingRef.current = false
    setDragged(null)
    onDragChange(false)
    if (!move) {
      setMoved((current) => (current?.settled ? null : current))
      return
    }
    const job = shown.find((each) => each.id === move.id)
    setMoved({ ids: move.ids, move })
    // useQueueMutation never rejects: it resolves to whether the move was saved
    const sent = moves.current.then(() => actions.move(job, move.target))
    moves.current = sent
    sent.then(() => settle(move))
  }

  const rows = shown.map((job, index) => ({ key: job.id, job, rank: index + 1 }))
    .filter(({ job }) => matchesFilter(job, filter))
  const columns = [
    {
      key: 'handle',
      width: 48,
      render: (_, { job }) => <DragHandle label={`Drag ${job.file.filename}`} disabled={!sortable} />
    },
    {
      key: 'position',
      title: '#',
      width: 40,
      render: (_, { rank }) => <Muted><span className={classes.position}>{rank}</span></Muted>
    },
    Table.EXPAND_COLUMN,
    { key: 'file', title: 'File', render: (_, { job }) => <JobFile job={job} /> },
    { key: 'needs', title: 'Needs', width: '18%', render: (_, { job }) => <Needs needs={job.needs} /> },
    {
      key: 'printers',
      title: 'Printers',
      width: 170,
      render: (_, { job }) => {
        const view = printersView(job)
        return <TwoLines title={view.title} detail={view.detail} />
      }
    },
    {
      key: 'next',
      title: 'What Happens Next',
      width: '28%',
      render: (_, { job }) => <WhatHappensNextCell job={job} onRelease={actions.release} />
    },
    {
      key: 'actions',
      width: 56,
      align: 'right',
      render: (_, { job, rank }) => (
        <WaitingMenu job={job} rank={rank} count={jobs.length} actions={actions} onCopies={onCopies} onShow={show} />
      )
    }
  ]
  const tags = paused && <Tag variant="filled" color="warning" className={classes.tag}>Dispatch paused</Tag>
  const filters = <Segmented options={WAITING_FILTERS} value={filter} onChange={setFilter} aria-label="Show" />

  return (
    <QueueSection title="Waiting" summary={waitingSummary(jobs)} tags={tags} extra={filters}>
      <div ref={tableRef}>
        <SortableRows ids={ids} nameOf={nameOf} onDragStart={startDrag} onDrop={drop}>
          <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
            scroll={{ x: 1120 }} locale={{ emptyText: EMPTY_TEXT[filter] }} components={SORTABLE_BODY}
            onRow={({ job }) => (job.whatHappensNext?.kind === 'BLOCKED' ? { style: { background: token.colorWarningBg } } : {})}
            expandable={{
              columnWidth: 40,
              expandIcon: ExpandButton,
              rowExpandable: ({ job }) => job.copies > 1,
              expandedRowRender: ({ job }) => (
                <BatchCopies job={job} live={live} now={now}
                  action={job.samePrinter && job.boundPrinter && <ReleaseToOthers job={job} onUnbind={actions.unbind} />} />
              ),
              // A dragged batch moves as one row: its copies fold away until the drop. Only its own: folding the
              // ones above would shift it away from the pointer.
              expandedRowKeys: dragged ? expanded.filter((key) => key !== dragged) : expanded,
              onExpandedRowsChange: (keys) => setExpanded(keys)
            }} />
        </SortableRows>
      </div>
    </QueueSection>
  )
}

const jobShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  copies: PropTypes.number.isRequired,
  copiesLeftToStart: PropTypes.number.isRequired,
  samePrinter: PropTypes.bool.isRequired,
  allCapable: PropTypes.bool,
  file: PropTypes.object.isRequired,
  boundPrinter: PropTypes.object,
  needs: PropTypes.object.isRequired,
  eligiblePrinters: PropTypes.arrayOf(PropTypes.object).isRequired,
  whatHappensNext: PropTypes.object,
  prints: PropTypes.arrayOf(PropTypes.object).isRequired
})

LoadFilament.propTypes = { printers: PropTypes.arrayOf(PropTypes.object).isRequired }
NextIcon.propTypes = { icon: PropTypes.string.isRequired }
// Only what it reads: the printer page's rows carry no copies (prints)
WhatHappensNextCell.propTypes = {
  job: PropTypes.shape({
    copiesLeftToStart: PropTypes.number.isRequired,
    eligiblePrinters: PropTypes.arrayOf(PropTypes.object).isRequired,
    whatHappensNext: PropTypes.object
  }).isRequired,
  printerId: PropTypes.string,
  onRelease: PropTypes.func
}
JobFile.propTypes = { job: jobShape.isRequired }
Needs.propTypes = { needs: PropTypes.object.isRequired }
BatchCopies.propTypes = {
  job: jobShape.isRequired,
  live: PropTypes.objectOf(PropTypes.object),
  now: PropTypes.number.isRequired,
  action: PropTypes.node
}
ExpandButton.propTypes = {
  expanded: PropTypes.bool,
  onExpand: PropTypes.func.isRequired,
  record: PropTypes.object.isRequired,
  expandable: PropTypes.bool
}
ReleaseToOthers.propTypes = { job: jobShape.isRequired, onUnbind: PropTypes.func.isRequired }
Waiting.propTypes = {
  jobs: PropTypes.arrayOf(jobShape).isRequired,
  paused: PropTypes.bool.isRequired,
  printing: PropTypes.arrayOf(PropTypes.object),
  now: PropTypes.number.isRequired,
  actions: actionsShape.isRequired,
  onCopies: PropTypes.func.isRequired,
  reveal: PropTypes.shape({ id: PropTypes.string.isRequired, at: PropTypes.number }),
  onDragChange: PropTypes.func
}
