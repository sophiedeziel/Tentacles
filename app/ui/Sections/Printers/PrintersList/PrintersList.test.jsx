import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { MemoryRouter } from 'react-router'

import PrintersList from './PrintersList'
import { FLEET_PAGE, NETWORK_PRINTERS, REMOVE_PRINTER, SET_PRINTER_FAVORITE } from './graphql/fleet'
import { POSSIBLE_TYPES, PRINT_QUEUE_CHANGED, PRINTER_STATUS_CHANGED, TYPE_POLICIES } from '../../Dashboard/graphql/dashboard'
import { ACTIONS } from '../../Dashboard/graphql/actions'
import { PRINTERS } from '../../Dashboard/widgets/Printer/fixtures'

const typed = (printer, { favorite = false, brand = null, model = null } = {}) => ({
  __typename: 'Printer',
  ...printer,
  uri: `http://192.168.1.${printer.id}/`,
  favorite,
  specs: { __typename: 'PrinterSpecs', brand, model, buildVolume: { __typename: 'RectangularBuildVolume', x: 250, y: 210, z: 220 } },
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

const FLEET = [
  typed(PRINTERS.PRINTING, { favorite: true, brand: 'Prusa Research', model: 'MK4' }),
  typed(PRINTERS.PAUSED), typed(PRINTERS.OPERATIONAL), typed(PRINTERS.ERROR), typed(PRINTERS.OFFLINE)
]
const network = (entries) => ({ networkPrinters: entries.map(([address, printer]) => ({
  __typename: 'NetworkPrinter', address, url: `http://${address}/`, printer: printer ? { __typename: 'Printer', id: printer } : null
})) })
const later = { delay: 60000 }

const renderPage = (printers = FLEET, mocks = [], { statusPush = later } = {}) => render(
  <MockedProvider cache={new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })} mocks={[
    { request: { query: FLEET_PAGE }, result: { data: { printers } }, maxUsageCount: 2 },
    { request: { query: NETWORK_PRINTERS }, result: { data: network([['192.168.1.57'], ['192.168.1.4', '4']]) } },
    { request: { query: PRINTER_STATUS_CHANGED }, result: { data: { printerStatusChanged: typed({ ...PRINTERS.ERROR, status: { ...PRINTERS.ERROR.status, errorText: 'Thermal runaway' } }) } }, ...statusPush },
    { request: { query: PRINT_QUEUE_CHANGED }, result: { data: { printQueueChanged: null } }, ...later },
    ...mocks
  ]}>
    <MemoryRouter initialEntries={['/printers/manage']}><PrintersList /></MemoryRouter>
  </MockedProvider>
)

const names = () => screen.getAllByRole('row').slice(1).map((row) => within(row).getAllByRole('link')[0].textContent)
const openMenu = async (name) => {
  await userEvent.click(await screen.findByRole('button', { name: `More actions for ${name}` }))
  return screen.findByRole('menu')
}

describe('PrintersList', () => {
  it('shows every printer, favorites first, with the fleet summary and the unsaved addresses on the network', async () => {
    renderPage()
    expect(await screen.findByText('Configured Printers')).toBeInTheDocument()
    expect(names()).toEqual(['Prusa MK4', 'Voron 2.4', 'Prusa Mini+', 'Ender 3 V2', 'Kobra 2'])
    expect(screen.getByText('Prusa Research MK4 · OctoPrint')).toBeInTheDocument()
    expect(screen.getByText('Needs Attention', { selector: '.ant-statistic-title' })).toBeInTheDocument()
    expect(await screen.findByText('1 OctoPrint instance found on your network')).toBeInTheDocument()
    expect(screen.getByText('192.168.1.57')).toBeInTheDocument()
    expect(screen.queryByText('192.168.1.4')).not.toBeInTheDocument()
  })

  it('filters the printers that need attention, and searches them', async () => {
    renderPage()
    await userEvent.click(await screen.findByText('Needs Attention', { selector: '.ant-segmented-item-label' }))
    expect(names()).toEqual(['Ender 3 V2', 'Kobra 2'])
    await userEvent.type(screen.getByRole('searchbox', { name: 'Search printers' }), 'kobra')
    expect(names()).toEqual(['Kobra 2'])
    await userEvent.type(screen.getByRole('searchbox', { name: 'Search printers' }), 'x')
    expect(screen.getByText('No printers match this search')).toBeInTheDocument()
  })

  it('saves the star and moves the printer up', async () => {
    renderPage(FLEET, [{
      request: { query: SET_PRINTER_FAVORITE, variables: { id: '7', favorite: true } },
      result: { data: { setPrinterFavorite: { __typename: 'SetPrinterFavoritePayload', printer: { __typename: 'Printer', id: '7', favorite: true }, errors: [] } } }
    }])
    await userEvent.click(await screen.findByRole('button', { name: 'Favorite Kobra 2', pressed: false }))
    expect(names()).toEqual(['Prusa MK4', 'Kobra 2', 'Voron 2.4', 'Prusa Mini+', 'Ender 3 V2'])
    expect(screen.getByRole('button', { name: 'Favorite Kobra 2', pressed: true })).toBeInTheDocument()
  })

  it('offers the main action for each state', async () => {
    renderPage()
    const buttonsOf = (name) => within(screen.getByText(name).closest('tr')).getAllByRole('button').map((button) => button.textContent)
    await screen.findByText('Kobra 2')
    expect(buttonsOf('Prusa MK4')).toContain('Open Queue')
    expect(buttonsOf('Ender 3 V2')).toContain('Reconnect')
    expect(buttonsOf('Kobra 2')).toContain('Edit Connection')
  })

  it.each([
    ['Prusa MK4', ['Edit Details', 'Open OctoPrint', 'Reconnect', 'Remove Printer']],
    ['Kobra 2', ['Edit Details', 'Open PrusaLink', 'Remove Printer']]
  ])('lists the menu of %s', async (name, items) => {
    renderPage(FLEET.map((printer) => (printer.id === '7' ? { ...printer, backend: 'PRUSALINK' } : printer)))
    const menu = await openMenu(name)
    expect(within(menu).getAllByRole('menuitem').map((item) => item.textContent)).toEqual(items)
    expect(within(menu).getByRole('link', { name: items[1] })).toHaveAttribute('target', '_blank')
  })

  it('reconnects an OctoPrint printer from its menu', async () => {
    let reconnected = false
    renderPage(FLEET, [{
      request: { query: ACTIONS.reconnect.document, variables: { printerId: '1' } },
      result: () => { reconnected = true; return { data: { reconnectPrinter: { __typename: 'ReconnectPrinterPayload', success: true, errors: [] } } } }
    }])
    await userEvent.click(within(await openMenu('Prusa MK4')).getByText('Reconnect'))
    await waitFor(() => expect(reconnected).toBe(true))
  })

  it('removes a printer after a confirmation in a modal', async () => {
    renderPage(FLEET, [{
      request: { query: REMOVE_PRINTER, variables: { id: '2' } },
      result: { data: { removePrinter: { __typename: 'RemovePrinterPayload', removedPrinterId: '2', errors: [] } } }
    }])
    await userEvent.click(within(await openMenu('Voron 2.4')).getByText('Remove Printer'))
    const dialog = await screen.findByRole('dialog', { name: 'Remove Voron 2.4?' })
    expect(within(dialog).getByText(/The printer itself is not touched/)).toBeInTheDocument()
    await userEvent.click(within(dialog).getByRole('button', { name: 'Remove Printer' }))
    await waitFor(() => expect(names()).toEqual(['Prusa MK4', 'Prusa Mini+', 'Ender 3 V2', 'Kobra 2']))
    expect(await screen.findByText('Voron 2.4 was removed')).toBeInTheDocument()
  })

  it('updates a row when its printer pushes a new status', async () => {
    renderPage(FLEET, [], { statusPush: { delay: 50 } })
    expect(await screen.findByText('Thermal runaway')).toBeInTheDocument()
  })

  it('shows the first-run empty state, with the scan banner under it', async () => {
    renderPage([])
    expect(await screen.findByText('No printers yet')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Add Printer/ })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Scan Network/ })).toBeInTheDocument()
    expect(screen.queryByText('Configured Printers')).not.toBeInTheDocument()
    expect(await screen.findByRole('button', { name: 'Connect 192.168.1.57' })).toBeInTheDocument()
  })
})
