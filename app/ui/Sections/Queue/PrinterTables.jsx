import React from 'react'
import PropTypes from 'prop-types'
import { Table } from 'antd'

import PrinterStatus from '../../components/PrinterStatus/PrinterStatus'
import { FileName, Muted, PrinterCell, QueueSection, printerShape } from './parts'
import { loadedText } from './queueView'

const statusOf = (printer) => printer.status || { stateFamily: 'OFFLINE', stateText: 'Offline' }

const STATE_COLUMN = {
  key: 'state',
  title: 'State',
  width: 160,
  render: (_, { printer }) => {
    const status = statusOf(printer)
    return <PrinterStatus family={status.stateFamily} text={status.stateText} />
  }
}

// Printers whose last print is still on the bed: first, since it's the one place a person must act. The bed is
// cleared by hand (Bed Cleared, with the queue's actions) before the printer takes the next job. Shows the print
// left on the bed when it's among the latest finished prints.
export function PrintersToClear ({ printers, lastPrints }) {
  const rows = printers.map((printer) => ({ key: printer.id, printer, print: lastPrints[printer.id] }))
  const columns = [
    {
      key: 'printer',
      title: 'Printer',
      render: (_, { printer }) => <PrinterCell printer={printer} subtitle="Waiting for its bed to be cleared" />
    },
    {
      key: 'onBed',
      title: 'On the Bed',
      render: (_, { print }) => (print ? <FileName file={print.printJob.file} /> : <Muted>Its last print</Muted>)
    },
    STATE_COLUMN
  ]

  return (
    <QueueSection title="Printers Waiting to Be Cleared" count={printers.length}>
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed" />
    </QueueSection>
  )
}

// The printers free for a job now (taking jobs, connected, idle, bed clear), with the filament they have loaded:
// what a waiting job's needs are matched against
export function AvailablePrinters ({ printers }) {
  const rows = printers.map((printer) => ({ key: printer.id, printer }))
  const columns = [
    {
      key: 'printer',
      title: 'Printer',
      render: (_, { printer }) => <PrinterCell printer={printer} subtitle={loadedText(printer.loadedFilaments)} />
    },
    STATE_COLUMN
  ]

  return (
    <QueueSection title="Available Printers" count={printers.length}>
      <Table columns={columns} dataSource={rows} pagination={false} size="middle" tableLayout="fixed"
        locale={{ emptyText: 'No printer is free for a job right now' }} />
    </QueueSection>
  )
}

PrintersToClear.propTypes = {
  printers: PropTypes.arrayOf(printerShape).isRequired,
  lastPrints: PropTypes.objectOf(PropTypes.object).isRequired
}
AvailablePrinters.propTypes = { printers: PropTypes.arrayOf(printerShape).isRequired }
