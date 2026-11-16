import React from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { GraphQLError } from 'graphql'
import { MemoryRouter, Route, Routes, useLocation, useParams } from 'react-router'

import PrinterAdd from './PrinterAdd'
import {
  ADD_NETWORK_PRINTERS, ADD_PRINTER, CANCEL_PRINTER_APP_KEY_REQUEST, IDENTIFY_PRINTER, PRINTER_APP_KEY_CHANGED,
  REQUEST_PRINTER_APP_KEY
} from './graphql/add'

const scan = (entries) => ({ data: { networkPrinters: entries.map(([address, printer]) => ({
  __typename: 'NetworkPrinter', address, url: `http://${address}/`, printer: printer ? { __typename: 'Printer', ...printer } : null
})) } })
const SCAN = scan([['192.168.1.57'], ['192.168.1.21', { id: '4', name: 'Prusa MK4' }]])
const appKeyRequest = (state, printer = null) => ({
  __typename: 'AppKeyRequest', id: 'r1', address: '192.168.1.57', state, approvalUrl: 'http://192.168.1.57/', error: null, printer
})

const requested = []
const REQUEST = {
  request: { query: REQUEST_PRINTER_APP_KEY, variables: { address: '192.168.1.57' } },
  result: () => {
    requested.push('192.168.1.57')
    return { data: { requestPrinterAppKey: { __typename: 'RequestPrinterAppKeyPayload', request: appKeyRequest('WAITING'), errors: [] } } }
  },
  maxUsageCount: 3
}
const pushed = (request, delay = 60000) => ({
  request: { query: PRINTER_APP_KEY_CHANGED, variables: { id: 'r1' } }, result: { data: { printerAppKeyChanged: request } }, delay
})
const CANCEL = {
  request: { query: CANCEL_PRINTER_APP_KEY_REQUEST, variables: { id: 'r1' } },
  result: { data: { cancelPrinterAppKeyRequest: { __typename: 'CancelPrinterAppKeyRequestPayload', request: { __typename: 'AppKeyRequest', id: 'r1', state: 'CANCELLED' }, errors: [] } } }
}

function PrinterPage () {
  return <p>Printer page {useParams().id}</p>
}

function Search () {
  return <output aria-label="search">{useLocation().search}</output>
}

const renderPage = (mocks = [], path = '/printers/add') => render(
  <MockedProvider mocks={[{ request: { query: ADD_NETWORK_PRINTERS }, result: SCAN }, ...mocks]}>
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/printers/add" element={<><PrinterAdd /><Search /></>} />
        <Route path="/printers/:id" element={<PrinterPage />} />
      </Routes>
    </MemoryRouter>
  </MockedProvider>
)

const row = async (address) => (await screen.findByText(address)).closest('li')
const currentStep = () => document.querySelector('.ant-steps-item-active .ant-steps-item-title').textContent

describe('PrinterAdd', () => {
  beforeEach(() => {
    requested.length = 0
    vi.spyOn(window, 'open').mockReturnValue(null)
  })
  afterEach(() => vi.restoreAllMocks())

  it('lists the OctoPrint servers on the network, the added ones with their printer', async () => {
    renderPage()
    expect(within(await row('192.168.1.57')).getByText('OctoPrint server, not added yet')).toBeInTheDocument()
    expect(within(await row('192.168.1.57')).getByRole('button', { name: 'Connect 192.168.1.57' })).toBeInTheDocument()
    expect(within(await row('192.168.1.21')).getByText('Already added as Prusa MK4')).toBeInTheDocument()
    expect(within(await row('192.168.1.21')).getByText('Added')).toBeInTheDocument()
    expect(currentStep()).toBe('Choose')
    expect(screen.queryByText(/CORS/)).not.toBeInTheDocument()
  })

  it('opens OctoPrint in the Connect click, waits for the approval, then opens the new printer', async () => {
    const tab = { opener: window, closed: false, close: vi.fn(), location: { href: '' }, document: { body: {} } }
    window.open.mockReturnValue(tab)
    renderPage([REQUEST, pushed(appKeyRequest('ADDED', { __typename: 'Printer', id: '9', name: 'Ender 3 V2' }), 200)])
    await userEvent.click(await screen.findByRole('button', { name: 'Connect 192.168.1.57' }))

    await screen.findByText('Waiting for you to approve Tentacles in OctoPrint')
    expect(window.open).toHaveBeenCalledWith('', '_blank')
    expect(tab.location.href).toBe('http://192.168.1.57/')
    const waiting = await row('192.168.1.57')
    expect(within(waiting).getByText('Waiting for you to approve Tentacles in OctoPrint')).toBeInTheDocument()
    expect(within(waiting).getByRole('button', { name: 'Open OctoPrint Again' })).not.toHaveClass('ant-btn-primary')
    expect(within(waiting).getByRole('button', { name: 'Cancel Request' })).toBeInTheDocument()
    expect(currentStep()).toBe('Approve in OctoPrint')

    expect(await screen.findByText('Printer page 9')).toBeInTheDocument()
  })

  it('makes Open OctoPrint the primary button when the browser blocked the tab', async () => {
    renderPage([REQUEST, pushed(appKeyRequest('DENIED'))])
    await userEvent.click(await screen.findByRole('button', { name: 'Connect 192.168.1.57' }))
    const open = await screen.findByRole('button', { name: 'Open OctoPrint' })
    expect(open).toHaveClass('ant-btn-primary')
    expect(window.open).toHaveBeenCalledOnce()
  })

  it('shows Connect again after Cancel Request', async () => {
    renderPage([REQUEST, pushed(appKeyRequest('DENIED')), CANCEL])
    await userEvent.click(await screen.findByRole('button', { name: 'Connect 192.168.1.57' }))
    await userEvent.click(await screen.findByRole('button', { name: 'Cancel Request' }))
    expect(within(await row('192.168.1.57')).getByText('OctoPrint server, not added yet')).toBeInTheDocument()
    expect(currentStep()).toBe('Choose')
  })

  it('starts the approval of ?connect= once without a pop-up, and drops the parameter', async () => {
    renderPage([REQUEST, pushed(appKeyRequest('DENIED'), 500)], '/printers/add?connect=192.168.1.57')
    expect(await screen.findByText('Waiting for you to approve Tentacles in OctoPrint')).toBeInTheDocument()
    expect(screen.getByLabelText('search')).toHaveTextContent(/^$/)
    expect(window.open).not.toHaveBeenCalled()

    const open = screen.getByRole('button', { name: 'Open OctoPrint' })
    expect(open).toHaveClass('ant-btn-primary')
    await userEvent.click(open)
    expect(window.open).toHaveBeenCalledWith('http://192.168.1.57/', '_blank', 'noopener,noreferrer')
    expect(screen.getByRole('button', { name: 'Open OctoPrint Again' })).not.toHaveClass('ant-btn-primary')

    expect(await screen.findByText(/OctoPrint did not approve Tentacles/)).toBeInTheDocument()
    expect(requested).toEqual(['192.168.1.57'])
  })

  it('scans again', async () => {
    renderPage([{ request: { query: ADD_NETWORK_PRINTERS, variables: { refresh: true } }, result: scan([['192.168.1.80']]) }])
    await userEvent.click(await screen.findByRole('button', { name: /Scan Again/ }))
    expect(await screen.findByText('192.168.1.80')).toBeInTheDocument()
    expect(screen.queryByText('192.168.1.57')).not.toBeInTheDocument()
  })

  it('switches the form to PrusaLink, tests the connection, adds the printer and opens it', async () => {
    const identity = { backend: 'PRUSALINK', uri: 'http://192.168.1.42', username: 'maker', secret: 'pass' }
    renderPage([
      { request: { query: IDENTIFY_PRINTER, variables: identity }, result: { data: { identifyPrinter: { __typename: 'PrinterIdentity', name: 'Prusa MK4', version: 'PrusaLink 2.1.2' } } } },
      {
        request: { query: ADD_PRINTER, variables: { input: { ...identity, name: 'Prusa MK4' } } },
        result: { data: { addPrinter: { __typename: 'AddPrinterPayload', printer: { __typename: 'Printer', id: '12', name: 'Prusa MK4' }, errors: [] } } }
      }
    ])
    expect(screen.getByLabelText('OctoPrint address')).toBeInTheDocument()
    expect(screen.getByText('In OctoPrint: Settings, Application Keys. Create one named Tentacles.')).toBeInTheDocument()

    await userEvent.click(screen.getByText('PrusaLink'))
    expect(screen.getByLabelText('Username')).toHaveValue('maker')
    expect(screen.getByText('Shown on the printer: Settings, Network, PrusaLink')).toBeInTheDocument()
    await userEvent.type(screen.getByLabelText('Address'), 'http://192.168.1.42')
    await userEvent.type(screen.getByLabelText('Password'), 'pass')
    expect(screen.getByRole('button', { name: 'Add Printer' })).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: 'Test Connection' }))
    expect(await screen.findByText('Prusa MK4, PrusaLink 2.1.2')).toBeInTheDocument()
    expect(screen.getByLabelText('Printer name')).toHaveValue('Prusa MK4')

    await userEvent.click(screen.getByRole('button', { name: 'Add Printer' }))
    expect(await screen.findByText('Printer page 12')).toBeInTheDocument()
  })

  it('asks for a full address before testing the connection (the API only takes absolute URLs)', async () => {
    renderPage()
    await userEvent.type(screen.getByLabelText('OctoPrint address'), '192.168.1.99')
    await userEvent.type(screen.getByLabelText('API key'), 'key')
    await userEvent.click(screen.getByRole('button', { name: 'Test Connection' }))
    expect(await screen.findByText('Enter a full address, e.g. http://octopi.local')).toBeInTheDocument()
  })

  it('keeps Add Printer locked when the printer is not reachable', async () => {
    const variables = { backend: 'OCTOPRINT', uri: 'http://192.168.1.99', username: null, secret: 'key' }
    renderPage([{
      request: { query: IDENTIFY_PRINTER, variables },
      result: { errors: [new GraphQLError('Could not reach http://192.168.1.99', { extensions: { code: 'UNREACHABLE' } })] }
    }])
    await userEvent.type(screen.getByLabelText('OctoPrint address'), 'http://192.168.1.99')
    await userEvent.type(screen.getByLabelText('API key'), 'key')
    await userEvent.click(screen.getByRole('button', { name: 'Test Connection' }))
    expect(await screen.findByText('Printer not reachable')).toBeInTheDocument()
    await waitFor(() => expect(screen.getByRole('button', { name: 'Add Printer' })).toBeDisabled())
  })
})
