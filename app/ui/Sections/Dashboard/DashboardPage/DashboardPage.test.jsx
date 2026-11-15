import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache, gql } from '@apollo/client'

import DashboardPage, { summary } from './DashboardPage'
import {
  DASHBOARD_CHANGED, DASHBOARD_PAGE, MONITOR_HEALTHY, POSSIBLE_TYPES, PRINT_QUEUE_CHANGED, PRINTER_STATUS_CHANGED,
  TYPE_POLICIES
} from '../graphql/dashboard'
import { ALL_OPTIONS, PRINTERS } from '../widgets/Printer/fixtures'

const typed = (printer) => ({
  __typename: 'Printer',
  ...printer,
  nextJob: printer.nextJob && {
    __typename: 'EnqueuedJob', ...printer.nextJob, executable: { __typename: 'File', ...printer.nextJob.executable }
  },
  status: {
    __typename: 'PrinterStatus',
    ...printer.status,
    hotend: printer.status.hotend && { __typename: 'TemperatureStatus', ...printer.status.hotend },
    bed: printer.status.bed && { __typename: 'TemperatureStatus', ...printer.status.bed },
    camera: { __typename: 'PrinterCamera', ...printer.status.camera }
  }
})

const widget = (id, printerId, widthUnits, heightUnits) => ({
  __typename: 'DashboardWidget', id, type: 'PRINTER', widthUnits, heightUnits,
  printer: { __typename: 'Printer', id: printerId },
  options: { __typename: 'PrinterWidgetOptions', ...ALL_OPTIONS, camera: false }
})

const page = (monitorHealthy = true) => ({
  dashboard: {
    __typename: 'Dashboard',
    updatedAt: null,
    sections: [
      { __typename: 'DashboardSection', id: '1', title: null, widgets: [widget('w1', '1', 2, 1)] },
      { __typename: 'DashboardSection', id: '2', title: 'Garage', widgets: [widget('w2', '4', 2, 1)] }
    ]
  },
  monitorHealthy,
  printers: [typed(PRINTERS.PRINTING), typed(PRINTERS.OPERATIONAL)]
})

// Prusa Mini+ started its next job: one job left, nothing to start
const queuePush = {
  __typename: 'Printer', id: '4', canStartNext: false, queuedCount: 1,
  nextJob: { __typename: 'EnqueuedJob', id: 'phone_stand.gcode', executable: { __typename: 'File', id: 'phone_stand.gcode', filename: 'phone_stand.gcode' } }
}

const renderPage = (data, monitorMock = { result: { data: { monitorHealthy: data.monitorHealthy } } }, queueDelay = 60000) => render(
  <MockedProvider
    cache={new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })}
    mocks={[
      { request: { query: DASHBOARD_PAGE }, result: { data } },
      { request: { query: MONITOR_HEALTHY }, ...monitorMock, maxUsageCount: 10 },
      { request: { query: PRINTER_STATUS_CHANGED }, result: { data: { printerStatusChanged: typed(PRINTERS.PAUSED) } }, delay: 60000 },
      { request: { query: DASHBOARD_CHANGED }, result: { data: { dashboardChanged: data.dashboard } }, delay: 60000 },
      { request: { query: PRINT_QUEUE_CHANGED }, result: { data: { printQueueChanged: queuePush } }, delay: queueDelay }
    ]}
  >
    <DashboardPage />
  </MockedProvider>
)

describe('DashboardPage', () => {
  it('summarizes the fleet in the header line', () => {
    expect(summary([PRINTERS.PRINTING, PRINTERS.OPERATIONAL, PRINTERS.PAUSED, PRINTERS.ERROR]))
      .toBe('4 printers · 1 printing · 6 jobs queued')
    expect(summary([{ ...PRINTERS.PAUSED }])).toBe('1 printer · 0 printing · 1 job queued')
  })

  it('renders the saved layout with each printer', async () => {
    renderPage(page())
    expect(await screen.findByText('2 printers · 1 printing · 5 jobs queued')).toBeInTheDocument()
    expect(screen.getByText('Prusa MK4')).toBeInTheDocument()
    expect(screen.getByText('Garage')).toBeInTheDocument()
    expect(screen.getByText('Prusa Mini+')).toBeInTheDocument()
    expect(screen.queryByText('Live data paused')).not.toBeInTheDocument()
  })

  it('warns that live data is paused when the monitor is not reporting', async () => {
    renderPage(page(false))
    expect(await screen.findByText('Live data paused')).toBeInTheDocument()
  })

  it('pauses live data when the monitor check fails', async () => {
    renderPage(page(), { error: new Error('Network error') })
    expect(await screen.findByText('Live data paused')).toBeInTheDocument()
    expect(screen.getByText("Tentacles can't be reached, so printer states may be out of date.")).toBeInTheDocument()
  })

  it('refreshes a printer\'s queue fields when its queue changes', async () => {
    renderPage(page(), undefined, 50)
    expect(await screen.findByText('2 printers · 1 printing · 5 jobs queued')).toBeInTheDocument()
    expect(await screen.findByText('2 printers · 1 printing · 4 jobs queued')).toBeInTheDocument()
    expect(screen.getByText('Up next: phone_stand.gcode')).toBeInTheDocument()
  })

  describe('cache', () => {
    const cache = () => new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })
    const STATUS = gql`fragment Status on Printer { id status { stateFamily stateText updatedAt } }`
    const write = (target, stateFamily, updatedAt) => target.writeFragment({
      fragment: STATUS,
      data: { __typename: 'Printer', id: '1', status: { __typename: 'PrinterStatus', stateFamily, stateText: stateFamily, updatedAt } }
    })
    const read = (target) => target.readFragment({ fragment: STATUS, id: 'Printer:1' }).status.stateFamily

    it('keeps the newest status when an older one arrives late', () => {
      const target = cache()
      write(target, 'PAUSED', '2026-11-14T19:02:10Z')
      write(target, 'PRINTING', '2026-11-14T19:00:00Z')
      expect(read(target)).toBe('PAUSED')
      write(target, 'OPERATIONAL', '2026-11-14T19:05:00Z')
      expect(read(target)).toBe('OPERATIONAL')
    })
  })
})
