import React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'react-router'
import { Table, theme } from 'antd'

import PrinterStatus from '../../components/PrinterStatus/PrinterStatus'
import { FilamentLine, Muted, QueueSection, TwoLines, printerShape } from './parts'
import { availableSummary, offlineText, takesNextView } from './queueView'
import * as classes from './QueuePage.module.less'

const statusOf = (printer) => printer.status || { stateFamily: 'OFFLINE', stateText: 'Offline' }

// The filament loaded in each of its slots, one per line
function LoadedFilaments ({ filaments = [] }) {
  if (filaments.length === 0) return <Muted>No filament set</Muted>
  return (
    <div className={classes.cell}>
      {filaments.map((filament) => <FilamentLine key={filament.slot} filament={filament} />)}
    </div>
  )
}

// Under the table: a line per printer that takes jobs but is offline, with what can bring it back
function OfflinePrinters ({ printers, renderAction }) {
  return printers.map((printer) => (
    <div key={printer.id} className={classes.footerLine}>
      <Muted>{offlineText(printer)}</Muted>
      {renderAction?.(printer)}
    </div>
  ))
}

// The printers free for a job: first the ones whose last print is still on the bed (the one place a person must
// act: highlighted while dispatch runs, with Bed Cleared), then the ones free now, then a line per offline printer.
// Takes Next says what the queue lines up for each one (Printer.takesNext, as if dispatch ran).
//
// `onBed`: the latest finished print by printer id (the print on a bed to clear, when it is among them).
// `renderAction(printer, { toClear })` and `renderOfflineAction(printer)`: the buttons of a row (Bed Cleared,
// Reconnect), from the page's actions.
export function AvailablePrinters ({ toClear, available, offline, paused, onBed, renderAction, renderOfflineAction }) {
  const { token } = theme.useToken()
  const rows = [
    ...toClear.map((printer) => ({ key: printer.id, printer, toClear: true })),
    ...available.map((printer) => ({ key: printer.id, printer, toClear: false }))
  ]
  const highlighted = (row) => row.toClear && !paused && row.printer.takesJobs !== false
  const columns = [
    {
      key: 'printer',
      title: 'Printer',
      render: (_, { printer }) => <Link to={`/printers/${printer.id}`} className={classes.strongLink}>{printer.name}</Link>
    },
    {
      key: 'state',
      title: 'State',
      width: 150,
      render: (_, { printer }) => {
        const status = statusOf(printer)
        return <PrinterStatus family={status.stateFamily} text={status.stateText} />
      }
    },
    {
      key: 'filament',
      title: 'Loaded Filament',
      width: '20%',
      render: (_, { printer }) => <LoadedFilaments filaments={printer.loadedFilaments} />
    },
    {
      key: 'next',
      title: 'Takes Next',
      width: '36%',
      render: (_, { printer, toClear: bed }) => {
        const view = takesNextView(printer, { paused, toClear: bed, onBed: onBed[printer.id] })
        return <TwoLines title={view.text} detail={view.detail} />
      }
    },
    {
      key: 'action',
      width: 136,
      align: 'right',
      render: (_, { printer, toClear: bed }) => renderAction?.(printer, { toClear: bed })
    }
  ]

  return (
    <QueueSection title="Available Printers" summary={availableSummary(rows.length, paused)}
      footer={<OfflinePrinters printers={offline} renderAction={renderOfflineAction} />}>
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
        scroll={{ x: 860 }} locale={{ emptyText: 'No printer is free for a job right now' }}
        onRow={(row) => (highlighted(row) ? { style: { background: token.colorPrimaryBg } } : {})} />
    </QueueSection>
  )
}

const queuePrinterShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  name: PropTypes.string.isRequired,
  takesJobs: PropTypes.bool,
  takesNext: PropTypes.object,
  loadedFilaments: PropTypes.arrayOf(PropTypes.object)
})

LoadedFilaments.propTypes = { filaments: PropTypes.arrayOf(PropTypes.object) }
OfflinePrinters.propTypes = { printers: PropTypes.arrayOf(printerShape).isRequired, renderAction: PropTypes.func }
AvailablePrinters.propTypes = {
  toClear: PropTypes.arrayOf(queuePrinterShape).isRequired,
  available: PropTypes.arrayOf(queuePrinterShape).isRequired,
  offline: PropTypes.arrayOf(printerShape).isRequired,
  paused: PropTypes.bool.isRequired,
  onBed: PropTypes.objectOf(PropTypes.object).isRequired,
  renderAction: PropTypes.func,
  renderOfflineAction: PropTypes.func
}
