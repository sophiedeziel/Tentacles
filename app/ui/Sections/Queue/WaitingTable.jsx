import React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'react-router'
import { Button, Dropdown, Table, Tag, Typography } from 'antd'
import { DownOutlined } from '@ant-design/icons'

import JobStatus from '../../components/JobStatus/JobStatus'
import { FilamentOutlined } from '../../components/icons'
import { FileName, Muted, QueueSection } from './parts'
import { batchView, needsView } from './queueView'
import whatHappensNext from './whatHappensNext'
import * as classes from './QueuePage.module.less'

// The words' tone, as antd Typography types (the theme's warning and error colours)
const TONES = { held: 'warning', paused: 'warning', blocked: 'danger', plain: undefined }

// Load Filament opens the page of a printer that could print the job once its filament is changed, where Loaded
// Filament is set: a link for one printer, a menu of them for more
function LoadFilament ({ printers }) {
  const label = <><FilamentOutlined aria-hidden /> Load Filament</>
  if (printers.length === 1) return <Link to={`/printers/${printers[0].id}`}>{label}</Link>

  const items = printers.map((printer) => ({
    key: printer.id,
    label: <Link to={`/printers/${printer.id}`}>{printer.name}</Link>
  }))
  return (
    <Dropdown menu={{ items }} trigger={['click']}>
      <Button type="link" size="small" style={{ paddingInline: 0, alignSelf: 'flex-start' }}>
        {label} <DownOutlined />
      </Button>
    </Dropdown>
  )
}

// What happens next to the job, in words (whatHappensNext.js)
function WhatHappensNextCell ({ job }) {
  const words = whatHappensNext(job.whatHappensNext, {
    copiesLeft: job.copiesLeftToStart, eligibleCount: job.eligiblePrinters.length
  })
  if (!words) return null

  return (
    <div className={classes.lines}>
      <Typography.Text type={TONES[words.tone]}>{words.text}</Typography.Text>
      {words.loadFilament && <LoadFilament printers={job.eligiblePrinters} />}
    </div>
  )
}

// The file, then its batch (× 10, copies left to start) and same-printer marks. Projects don't exist yet: their
// name comes here with them.
function JobFile ({ job }) {
  const batch = batchView(job)

  return (
    <div className={classes.cell}>
      <div className={classes.fileLine}>
        <FileName file={job.file} />
        {batch && <Tag variant="filled" style={{ marginInlineEnd: 0 }}>{batch.size}</Tag>}
        {job.samePrinter && <Tag variant="filled" color="purple" style={{ marginInlineEnd: 0 }}>Same printer</Tag>}
      </div>
      {batch && <Muted small>{batch.left}</Muted>}
    </div>
  )
}

// Material and colour per tool, then the footprint
function Needs ({ needs }) {
  const view = needsView(needs)
  if (view.pending) return <Muted>Reading the G-code</Muted>
  if (view.unknown) return <Muted>Not known</Muted>

  return (
    <div className={classes.lines}>
      {view.filaments.map((filament) => <span key={filament.key}>{filament.text}</span>)}
      {view.footprint && <Muted small>{view.footprint}</Muted>}
      {view.filaments.length === 0 && !view.footprint && <Muted>Nothing known</Muted>}
    </div>
  )
}

// The printers that can take it. A same-printer batch that started is bound to its printer: only that one.
function Printers ({ job }) {
  if (job.samePrinter && job.boundPrinter) {
    return <span>Bound to <Link to={`/printers/${job.boundPrinter.id}`}>{job.boundPrinter.name}</Link></span>
  }
  if (job.eligiblePrinters.length === 0) return <Muted>None</Muted>
  return <span>{job.eligiblePrinters.map((printer) => printer.name).join(', ')}</span>
}

// A batch's copies, under its row: each copy handed to a printer, then how many are left to start
export function BatchCopies ({ job }) {
  const rows = job.prints.map((print) => ({ key: print.id, print }))
  const columns = [
    { key: 'copy', title: 'Copy', width: 100, render: (_, { print }) => `Copy ${print.copyNumber}` },
    {
      key: 'printer',
      title: 'Printer',
      render: (_, { print }) => <Link to={`/printers/${print.printer.id}`}>{print.printer.name}</Link>
    },
    { key: 'status', title: 'Status', width: 200, render: (_, { print }) => <CopyStatus print={print} /> }
  ]

  return (
    <div className={classes.copies}>
      {rows.length > 0 && (
        <Table columns={columns} dataSource={rows} pagination={false} size="small" tableLayout="fixed" />
      )}
      <Muted small>
        {job.copiesLeftToStart === 1 ? '1 copy left to start' : `${job.copiesLeftToStart} copies left to start`}
      </Muted>
    </div>
  )
}

// A copy's status: Starting or Printing (with how far it got) while under way, then how it ended
function CopyStatus ({ print }) {
  if (print.status === 'ENQUEUED') return <Tag variant="filled" color="purple" style={{ marginInlineEnd: 0 }}>Starting</Tag>
  if (print.status === 'ACTIVE') {
    return <Tag variant="filled" color="purple" style={{ marginInlineEnd: 0 }}>Printing · {Math.round(print.progress)}%</Tag>
  }
  return <JobStatus status={(print.result || print.status).toLowerCase()} />
}

// The jobs with copies left to start, in queue order. A batch is one row (it moves as one) and expands to its
// copies. Labelled Dispatch paused while nothing starts.
export function Waiting ({ jobs, paused }) {
  const rows = jobs.map((job, index) => ({ key: job.id, job, rank: index + 1 }))
  const columns = [
    {
      key: 'position',
      title: '#',
      width: 56,
      render: (_, { rank }) => <Muted><span className={classes.position}>{rank}</span></Muted>
    },
    { key: 'file', title: 'File', render: (_, { job }) => <JobFile job={job} /> },
    { key: 'needs', title: 'Needs', width: 200, render: (_, { job }) => <Needs needs={job.needs} /> },
    { key: 'printers', title: 'Printers', width: 200, render: (_, { job }) => <Printers job={job} /> },
    { key: 'next', title: 'What Happens Next', width: 280, render: (_, { job }) => <WhatHappensNextCell job={job} /> }
  ]
  const tags = paused && <Tag variant="filled" color="warning" style={{ marginInlineEnd: 0 }}>Dispatch paused</Tag>

  return (
    <QueueSection title="Waiting" count={jobs.length} tags={tags}>
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
        scroll={{ x: 960 }} locale={{ emptyText: 'Nothing is waiting' }}
        expandable={{
          rowExpandable: ({ job }) => job.copies > 1,
          expandedRowRender: ({ job }) => <BatchCopies job={job} />
        }} />
    </QueueSection>
  )
}

const jobShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  copies: PropTypes.number.isRequired,
  copiesLeftToStart: PropTypes.number.isRequired,
  samePrinter: PropTypes.bool.isRequired,
  file: PropTypes.object.isRequired,
  boundPrinter: PropTypes.object,
  needs: PropTypes.object.isRequired,
  eligiblePrinters: PropTypes.arrayOf(PropTypes.object).isRequired,
  whatHappensNext: PropTypes.object,
  prints: PropTypes.arrayOf(PropTypes.object).isRequired
})

LoadFilament.propTypes = { printers: PropTypes.arrayOf(PropTypes.object).isRequired }
WhatHappensNextCell.propTypes = { job: jobShape.isRequired }
JobFile.propTypes = { job: jobShape.isRequired }
Needs.propTypes = { needs: PropTypes.object.isRequired }
Printers.propTypes = { job: jobShape.isRequired }
BatchCopies.propTypes = { job: jobShape.isRequired }
CopyStatus.propTypes = { print: PropTypes.object.isRequired }
Waiting.propTypes = { jobs: PropTypes.arrayOf(jobShape).isRequired, paused: PropTypes.bool.isRequired }
