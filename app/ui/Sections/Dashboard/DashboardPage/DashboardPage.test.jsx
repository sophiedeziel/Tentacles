import React from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache, gql } from '@apollo/client'

import DashboardPage, { summary } from './DashboardPage'
import {
  DASHBOARD_CHANGED, DASHBOARD_PAGE, DEFAULT_DASHBOARD, MONITOR_HEALTHY, POSSIBLE_TYPES, PRINT_QUEUE_CHANGED,
  PRINTER_STATUS_CHANGED, SAVE_DASHBOARD, TYPE_POLICIES
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

const renderPage = (
  data, monitorMock = { result: { data: { monitorHealthy: data.monitorHealthy } } }, queueDelay = 60000, mocks = [],
  layoutDelay = 60000
) => render(
  <MockedProvider
    cache={new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })}
    mocks={[
      { request: { query: DASHBOARD_PAGE }, result: { data } },
      { request: { query: MONITOR_HEALTHY }, ...monitorMock, maxUsageCount: 10 },
      { request: { query: PRINTER_STATUS_CHANGED }, result: { data: { printerStatusChanged: typed(PRINTERS.PAUSED) } }, delay: 60000 },
      { request: { query: DASHBOARD_CHANGED }, result: { data: { dashboardChanged: data.dashboard } }, delay: layoutDelay },
      { request: { query: PRINT_QUEUE_CHANGED }, result: { data: { printQueueChanged: queuePush } }, delay: queueDelay },
      ...mocks
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

  describe('edit mode', () => {
    // A desktop screen: every breakpoint matches
    const smallScreen = window.matchMedia
    beforeEach(() => {
      window.matchMedia = (query) => ({
        matches: true, media: query, addListener: vi.fn(), removeListener: vi.fn(), addEventListener: vi.fn(), removeEventListener: vi.fn()
      })
    })
    afterEach(() => { window.matchMedia = smallScreen })

    const printerInput = (id, printerId) => ({
      id, type: 'PRINTER', widthUnits: 2, heightUnits: 1, printerId, options: { printer: { ...ALL_OPTIONS, camera: false } }
    })
    // The page's layout with a divider added
    const sections = [
      { id: '1', title: null, widgets: [printerInput('w1', '1')] },
      { id: '2', title: 'Garage', widgets: [printerInput('w2', '4')] },
      { id: null, title: 'New Section', widgets: [] }
    ]
    const save = (result, delay = 0) => ({
      request: { query: SAVE_DASHBOARD, variables: { sections } }, result: { data: { saveDashboard: result } }, delay
    })
    const editPage = async (mocks, layoutDelay) => {
      renderPage(page(), undefined, 60000, mocks, layoutDelay)
      await userEvent.click(await screen.findByRole('button', { name: /Edit Dashboard/ }))
    }

    it('saves the draft on Done and leaves edit mode', async () => {
      const saved = page().dashboard
      saved.sections.push({ __typename: 'DashboardSection', id: '3', title: 'New Section', widgets: [] })
      await editPage([save({ __typename: 'SaveDashboardPayload', dashboard: saved, errors: [] }, 200)])
      expect(screen.getByText(/Drag a widget and the dashboard rearranges/)).toBeInTheDocument()
      await userEvent.click(screen.getByRole('button', { name: 'Add Divider' }))
      expect(screen.getAllByRole('textbox', { name: 'Section name' }).map((input) => input.value)).toEqual(['Garage', 'New Section'])
      await userEvent.click(screen.getByRole('button', { name: 'Done' }))
      // The draft can't change while it saves
      expect(screen.getByRole('region', { name: 'Garage' }).closest('[inert]')).not.toBeNull()
      expect(await screen.findByRole('button', { name: /Edit Dashboard/ })).toBeInTheDocument()
      expect(screen.getByText('New Section')).toBeInTheDocument()
      expect(screen.queryByRole('textbox')).not.toBeInTheDocument()
    })

    it('asks for a title on every divider before saving', async () => {
      await editPage([])
      await userEvent.clear(screen.getByRole('textbox', { name: 'Section name' }))
      await userEvent.click(screen.getByRole('button', { name: 'Done' }))
      expect(screen.getByText('Every divider needs a title')).toBeInTheDocument()
      expect(screen.getByRole('textbox', { name: 'Section name' })).toHaveClass('ant-input-status-error')
    })

    it('shows why the layout was not saved and keeps editing', async () => {
      await editPage([save({ __typename: 'SaveDashboardPayload', dashboard: null, errors: ["Section 3: Title can't be blank"] })])
      await userEvent.click(screen.getByRole('button', { name: 'Add Divider' }))
      await userEvent.click(screen.getByRole('button', { name: 'Done' }))
      expect(await screen.findByText("The layout wasn't saved")).toBeInTheDocument()
      expect(screen.getByText("Section 3: Title can't be blank")).toBeInTheDocument()
      // Still editing (antd keeps the loading icon until its exit animation, which jsdom never ends)
      expect(screen.getByRole('button', { name: /Done/ })).toBeInTheDocument()
    })

    it('adds a widget from the gallery at the end of the last section', async () => {
      await editPage([])
      await userEvent.click(screen.getByRole('button', { name: /Add Widget/ }))
      await userEvent.click(await screen.findByRole('button', { name: 'Choose Printer, Small' }))
      await userEvent.click(screen.getByRole('button', { name: 'Add Printer (Small) widget for Prusa MK4' }))
      const garage = screen.getByRole('region', { name: 'Garage' })
      expect(within(garage).getAllByRole('button', { name: /^Remove Prusa/ }).map((button) => button.getAttribute('aria-label')))
        .toEqual(['Remove Prusa Mini+', 'Remove Prusa MK4'])
    })

    it('keeps the draft when the layout changes elsewhere', async () => {
      await editPage([], 300)
      await userEvent.click(screen.getByRole('button', { name: 'Add Divider' }))
      expect(await screen.findByText('Layout changed elsewhere', {}, { timeout: 3000 })).toBeInTheDocument()
      expect(screen.getAllByRole('textbox', { name: 'Section name' })).toHaveLength(2)
    })

    it('clicks a widget tool with the keyboard instead of picking the widget up', async () => {
      await editPage([])
      screen.getByRole('button', { name: 'Remove Prusa MK4' }).focus()
      await userEvent.keyboard('{Enter}')
      expect(screen.queryByRole('button', { name: 'Remove Prusa MK4' })).not.toBeInTheDocument()
      expect(screen.queryByText('Drop at the end of this row')).not.toBeInTheDocument()
    })

    it('says the layout changed elsewhere when another save lands during a save that fails', async () => {
      await editPage([{
        request: { query: SAVE_DASHBOARD, variables: { sections: sections.slice(0, 2) } },
        result: { data: { saveDashboard: { __typename: 'SaveDashboardPayload', dashboard: null, errors: ['Try again'] } } },
        delay: 1000
      }], 500)
      await userEvent.click(screen.getByRole('button', { name: 'Done' }))
      expect(await screen.findByText("The layout wasn't saved", {}, { timeout: 3000 })).toBeInTheDocument()
      expect(screen.getByText('Layout changed elsewhere')).toBeInTheDocument()
    })

    it('picks a widget up with the keyboard and puts it back on Esc', async () => {
      await editPage([])
      const cell = screen.getByRole('button', { name: 'Prusa MK4' })
      cell.focus()
      await userEvent.keyboard(' ')
      expect(await screen.findAllByText('Drop at the end of this row')).toHaveLength(2)
      await userEvent.keyboard('{Escape}')
      await waitFor(() => expect(screen.queryByText('Drop at the end of this row')).not.toBeInTheDocument())
      expect(screen.getByRole('button', { name: 'Prusa MK4' })).toBeInTheDocument()
    })

    it('loads the default layout into the draft on Reset Layout', async () => {
      const defaults = {
        __typename: 'Dashboard',
        updatedAt: null,
        sections: [{ __typename: 'DashboardSection', id: null, title: null, widgets: [{ ...widget(null, '4', 2, 1) }] }]
      }
      await editPage([{ request: { query: DEFAULT_DASHBOARD }, result: { data: { defaultDashboard: defaults } } }])
      expect(screen.getByRole('textbox', { name: 'Section name' })).toBeInTheDocument()
      await userEvent.click(screen.getByRole('button', { name: 'Reset Layout' }))
      await waitFor(() => expect(screen.queryByRole('textbox', { name: 'Section name' })).not.toBeInTheDocument())
      expect(screen.getByText('Prusa Mini+')).toBeInTheDocument()
      expect(screen.queryByText('Prusa MK4')).not.toBeInTheDocument()
    })
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

  it('offers edit mode on desktop screens only', async () => {
    renderPage(page())
    expect(await screen.findByText('Prusa MK4')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Edit Dashboard/ })).not.toBeInTheDocument()
  })
})
