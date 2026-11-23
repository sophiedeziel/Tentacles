import React, { useState } from 'react'
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

// The jobs with copies left to start, in queue order, filtered by what happens next to them (WAITING_FILTERS: the
// "#" stays each job's place in the whole queue). A batch is one row and expands to its copies; a blocked one is
// tinted. Tagged Dispatch paused while no printer takes a job.
// `printing`: the Printing rows, for the progress of a batch's copies.
export function Waiting ({ jobs, paused, printing = [], now }) {
  const { token } = theme.useToken()
  const [filter, setFilter] = useState('All')
  const [expanded, setExpanded] = useState([])
  const live = Object.fromEntries(printing.map((print) => [print.id, print]))

  const rows = jobs.map((job, index) => ({ key: job.id, job, rank: index + 1 }))
    .filter(({ job }) => matchesFilter(job, filter))
  const columns = [
    {
      key: 'position',
      title: '#',
      width: 48,
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
    { key: 'next', title: 'What Happens Next', width: '28%', render: (_, { job }) => <WhatHappensNextCell job={job} /> }
  ]
  const tags = paused && <Tag variant="filled" color="warning" className={classes.tag}>Dispatch paused</Tag>
  const filters = <Segmented options={WAITING_FILTERS} value={filter} onChange={setFilter} aria-label="Show" />

  return (
    <QueueSection title="Waiting" summary={waitingSummary(jobs)} tags={tags} extra={filters}>
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
        scroll={{ x: 1060 }} locale={{ emptyText: EMPTY_TEXT[filter] }}
        onRow={({ job }) => (job.whatHappensNext?.kind === 'BLOCKED' ? { style: { background: token.colorWarningBg } } : {})}
        expandable={{
          columnWidth: 40,
          expandIcon: ExpandButton,
          rowExpandable: ({ job }) => job.copies > 1,
          expandedRowRender: ({ job }) => <BatchCopies job={job} live={live} now={now} />,
          expandedRowKeys: expanded,
          onExpandedRowsChange: (keys) => setExpanded(keys)
        }} />
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
Waiting.propTypes = {
  jobs: PropTypes.arrayOf(jobShape).isRequired,
  paused: PropTypes.bool.isRequired,
  printing: PropTypes.arrayOf(PropTypes.object),
  now: PropTypes.number.isRequired
}
