import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Link, useNavigate } from 'react-router'
import { Button, Card, Input, Segmented, Table } from 'antd'
import { StarFilled, StarOutlined } from '@ant-design/icons'

import PrinterStatus from '../../../components/PrinterStatus/PrinterStatus'
import PrintProgress from '../../../components/PrintProgress/PrintProgress'
import { Printer3DOutlined } from '../../../components/icons'
import useFavorite from '../useFavorite'
import fleetView, { FILTERS, filterFleet } from './fleetView'
import RowMenu, { usePrinterAction } from './RowMenu'
import * as classes from './PrintersList.module.less'

// Saved on click; the cache update re-sorts the list at once
function FavoriteStar ({ printer }) {
  const toggle = useFavorite(printer)
  const { favorite, name } = printer

  return (
    <Button type="text" aria-pressed={favorite} aria-label={`Favorite ${name}`} onClick={toggle}
      className={favorite ? classes.starOn : classes.star} icon={favorite ? <StarFilled /> : <StarOutlined />} />
  )
}

// Edit Connection and Open Queue open a page; Connect and Reconnect run at once (they don't touch a print)
function MainAction ({ printer, action }) {
  const navigate = useNavigate()
  const runAction = usePrinterAction()
  const [running, setRunning] = useState(false)

  const onClick = async () => {
    if (action.to) return navigate(action.to)
    setRunning(true)
    await runAction(action.key, printer)
    setRunning(false)
  }
  return <Button size="small" loading={running} onClick={onClick}>{action.label}</Button>
}

const muted = (text) => <span className={classes.muted}>{text}</span>

const COLUMNS = [
  { key: 'favorite', width: 48, render: (_, { printer }) => <FavoriteStar printer={printer} /> },
  {
    key: 'printer',
    title: 'Printer',
    render: (_, { printer, view }) => (
      <div className={classes.printer}>
        <span className={view.tinted ? classes.avatarTinted : classes.avatar}><Printer3DOutlined aria-hidden /></span>
        <div className={classes.names}>
          <Link to={`/printers/${printer.id}`} className={classes.name}>{printer.name}</Link>
          <span className={classes.subtitle} title={`${view.brandModel || 'No brand or model'} · ${view.product}`}>
            {view.brandModel || <Link to={`/printers/${printer.id}`}>Add brand and model</Link>} · {view.product}
          </span>
        </div>
      </div>
    )
  },
  {
    key: 'state', title: 'State', width: 150,
    render: (_, { view }) => <PrinterStatus family={view.family} text={view.stateText} />
  },
  {
    key: 'now',
    title: 'Now',
    width: 240,
    render: (_, { view }) => (view.job
      ? (
        <div className={classes.job}>
          <span className={classes.fileName} title={view.job.fileName}>{view.job.fileName}</span>
          <PrintProgress family={view.family} progress={view.job.progress} timeLeft={view.job.timeLeft} />
        </div>
        )
      : <span className={view.now.muted ? classes.muted : undefined}>{view.now.text}</span>)
  },
  { key: 'buildVolume', title: 'Build Volume', width: 160, className: classes.nowrap, render: (_, { view }) => view.buildVolume || muted('Not set') },
  {
    key: 'queue', title: 'Queue', width: 104,
    render: (_, { view }) => (view.queue ? <Link to={view.queue.to}>{view.queue.text}</Link> : muted('Empty'))
  },
  {
    key: 'actions',
    title: 'Actions',
    width: 200,
    align: 'right',
    render: (_, { printer, view }) => (
      <div className={classes.actions}>
        <MainAction printer={printer} action={view.mainAction} />
        <RowMenu printer={printer} view={view} />
      </div>
    )
  }
]

// The Configured Printers card: the filter, the search and a row per printer, favorites first
export default function FleetTable ({ printers, now }) {
  const [filter, setFilter] = useState('All')
  const [search, setSearch] = useState('')
  const rows = filterFleet(printers, { filter, search })
    .map((printer) => ({ key: printer.id, printer, view: fleetView(printer, now) }))

  let empty = 'No printers match this search'
  if (!search.trim() && filter === 'Favorites') empty = 'No favorites yet: star a printer to keep it at the top'
  if (!search.trim() && filter === 'Needs Attention') empty = 'No printer needs attention'

  return (
    <Card title="Configured Printers" className={classes.card} styles={{ body: { padding: 0 } }}
      extra={
        <div className={classes.tools}>
          <Segmented options={FILTERS} value={filter} onChange={setFilter} />
          <Input.Search placeholder="Search printers" aria-label="Search printers" allowClear
            value={search} onChange={(event) => setSearch(event.target.value)} style={{ width: 220 }} />
        </div>
      }>
      <Table columns={COLUMNS} dataSource={rows} pagination={false} scroll={{ x: 1040 }} tableLayout="fixed" size="middle"
        locale={{ emptyText: empty }} />
    </Card>
  )
}

const printerShape = PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string.isRequired })

FavoriteStar.propTypes = {
  printer: PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string, favorite: PropTypes.bool }).isRequired
}
MainAction.propTypes = {
  printer: printerShape.isRequired,
  action: PropTypes.shape({ key: PropTypes.string.isRequired, label: PropTypes.string.isRequired, to: PropTypes.string })
    .isRequired
}
FleetTable.propTypes = { printers: PropTypes.arrayOf(printerShape).isRequired, now: PropTypes.number.isRequired }
