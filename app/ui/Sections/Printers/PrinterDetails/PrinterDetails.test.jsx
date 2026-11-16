import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { GraphQLError } from 'graphql'
import { createMemoryRouter } from 'react-router'
import { RouterProvider } from 'react-router/dom'

import PrinterDetails from './PrinterDetails'
import { IDENTIFY_SAVED_PRINTER, PRINTER_DETAILS, PRINTER_VERSION, UPDATE_PRINTER } from './graphql/details'
import { REMOVE_PRINTER, SET_PRINTER_FAVORITE } from '../PrintersList/graphql/fleet'
import { POSSIBLE_TYPES, PRINT_QUEUE_CHANGED, PRINTER_STATUS_CHANGED, TYPE_POLICIES } from '../../Dashboard/graphql/dashboard'
import { PRINTERS } from '../../Dashboard/widgets/Printer/fixtures'

const { status } = PRINTERS.PRINTING
const PRINTER = {
  __typename: 'Printer',
  ...PRINTERS.PRINTING,
  backend: 'PRUSALINK',
  uri: 'http://192.168.1.21',
  username: 'maker',
  favorite: false,
  nextJob: { __typename: 'EnqueuedJob', ...PRINTERS.PRINTING.nextJob, executable: { __typename: 'File', ...PRINTERS.PRINTING.nextJob.executable } },
  status: {
    __typename: 'PrinterStatus',
    ...status,
    hotend: { __typename: 'TemperatureStatus', ...status.hotend },
    bed: { __typename: 'TemperatureStatus', ...status.bed },
    camera: { __typename: 'PrinterCamera', ...status.camera }
  }
}
const later = { delay: 60000 }
const BASE_MOCKS = [
  { request: { query: PRINTER_DETAILS, variables: { id: '1' } }, result: { data: { printer: PRINTER } } },
  { request: { query: PRINTER_VERSION, variables: { id: '1' } }, result: { data: { printer: { __typename: 'Printer', id: '1', version: 'PrusaLink 2.1.2 (firmware 6.2.0)' } } } },
  { request: { query: PRINTER_STATUS_CHANGED }, result: { data: { printerStatusChanged: PRINTER } }, ...later },
  { request: { query: PRINT_QUEUE_CHANGED }, result: { data: { printQueueChanged: null } }, ...later }
]

const renderPage = (mocks = [], baseMocks = BASE_MOCKS) => {
  const cache = new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })
  const router = createMemoryRouter([
    { path: '/printers/:id', element: <PrinterDetails /> },
    { path: '/printers/manage', element: <p>Fleet list</p> },
    { path: '/printers/:id/queue', element: <p>Queue</p> }
  ], { initialEntries: ['/printers/1'] })
  render(<MockedProvider cache={cache} mocks={[...baseMocks, ...mocks]}><RouterProvider router={router} /></MockedProvider>)
  return { cache, router }
}

const updated = (input, printer = {}) => ({
  request: { query: UPDATE_PRINTER, variables: { input: { id: '1', ...input } } },
  result: { data: { updatePrinter: { __typename: 'UpdatePrinterPayload', printer: { __typename: 'Printer', id: '1', name: PRINTER.name, uri: PRINTER.uri, username: 'maker', ...printer }, errors: [] } } }
})
const identify = (secret, result) => ({
  request: {
    query: IDENTIFY_SAVED_PRINTER,
    variables: { backend: 'PRUSALINK', uri: 'http://192.168.1.21', username: 'maker', secret, printerId: '1' }
  },
  result
})
const field = (label) => screen.getByLabelText(label)
const save = () => userEvent.click(screen.getByRole('button', { name: /Save Changes/ }))

describe('PrinterDetails', () => {
  it('shows the printer, its live state and its connection, with the password left blank', async () => {
    renderPage()
    expect(await screen.findByRole('heading', { name: 'Prusa MK4' })).toBeInTheDocument()
    expect(screen.getByText('Printing')).toBeInTheDocument()
    expect(screen.getByText('PrusaLink', { selector: '.ant-tag' })).toBeInTheDocument()
    expect(field('Address')).toHaveValue('http://192.168.1.21')
    expect(field('Username')).toHaveValue('maker')
    expect(field('Password')).toHaveValue('')
    expect(field('Password')).toHaveAttribute('placeholder', 'Leave blank to keep the current password')
    expect(screen.getByText(/The saved password is never shown/)).toBeInTheDocument()
    expect(await screen.findByText('PrusaLink 2.1.2 (firmware 6.2.0)')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Save Changes/ })).toBeDisabled()
  })

  it('says when there is no such printer', async () => {
    renderPage([], [{ request: { query: PRINTER_DETAILS, variables: { id: '1' } }, result: { data: { printer: null } } }, ...BASE_MOCKS.slice(2)])
    expect(await screen.findByText('Printer not found')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Back to Printers' })).toHaveAttribute('href', '/printers/manage')
  })

  it('saves only the changed fields, without the blank password', async () => {
    renderPage([updated({ uri: 'http://192.168.1.22' }, { uri: 'http://192.168.1.22' })])
    await userEvent.clear(await screen.findByLabelText('Address'))
    await userEvent.type(field('Address'), 'http://192.168.1.22')
    await save()
    expect(await screen.findByText('Changes saved')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Save Changes/ })).toBeDisabled()
  })

  it('asks for a full address instead of saving one without a scheme', async () => {
    renderPage()
    await userEvent.clear(await screen.findByLabelText('Address'))
    await userEvent.type(field('Address'), '192.168.1.22')
    await save()
    expect(await screen.findByText('Enter a full address, e.g. http://192.168.1.42')).toBeInTheDocument()
    expect(screen.queryByText('Changes saved')).not.toBeInTheDocument()
  })

  it('sends the password once one is typed, then blanks it again', async () => {
    renderPage([updated({ secret: 'new pass' })])
    await userEvent.type(await screen.findByLabelText('Password'), 'new pass')
    await save()
    expect(await screen.findByText('Changes saved')).toBeInTheDocument()
    expect(field('Password')).toHaveValue('')
  })

  it('tests the connection with the saved password when none is typed', async () => {
    renderPage([identify(null, { data: { identifyPrinter: { __typename: 'PrinterIdentity', name: 'Prusa MK4', version: 'PrusaLink 2.1.3' } } })])
    await userEvent.click(await screen.findByRole('button', { name: /Test Connection/ }))
    expect(await screen.findByText('Connected')).toBeInTheDocument()
    expect(screen.getByText('PrusaLink 2.1.3')).toBeInTheDocument()

    // The answer was for the saved password
    await userEvent.type(field('Password'), 'x')
    expect(screen.queryByText('Connected')).not.toBeInTheDocument()
  })

  it('tells a wrong password from an unreachable printer', async () => {
    const failure = (code, message) => ({ errors: [new GraphQLError(message, { extensions: { code } })] })
    renderPage([
      identify(null, failure('UNREACHABLE', 'Could not reach PrusaLink at http://192.168.1.21: timeout')),
      identify('nope', failure('UNAUTHORIZED', 'PrusaLink rejected the username or password'))
    ])
    await userEvent.click(await screen.findByRole('button', { name: /Test Connection/ }))
    expect(await screen.findByText('Printer not reachable')).toBeInTheDocument()

    await userEvent.type(field('Password'), 'nope')
    await userEvent.click(screen.getByRole('button', { name: /Test Connection/ }))
    expect(await screen.findByText('Wrong password')).toBeInTheDocument()
  })

  it('saves the favorite on click, outside the form', async () => {
    renderPage([{
      request: { query: SET_PRINTER_FAVORITE, variables: { id: '1', favorite: true } },
      result: { data: { setPrinterFavorite: { __typename: 'SetPrinterFavoritePayload', printer: { __typename: 'Printer', id: '1', favorite: true }, errors: [] } } }
    }])
    await userEvent.click(await screen.findByRole('button', { name: /Add to Favorites/ }))
    expect(await screen.findByRole('button', { name: /^star Favorite$/ })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: /Save Changes/ })).toBeDisabled()
  })

  it('removes the printer after the confirmation, forgets it and goes back to the fleet list', async () => {
    const warn = vi.spyOn(console, 'warn')
    const { cache, router } = renderPage([{
      request: { query: REMOVE_PRINTER, variables: { id: '1' } },
      result: { data: { removePrinter: { __typename: 'RemovePrinterPayload', removedPrinterId: '1', errors: [] } } }
    }])
    // Even with unsaved changes: removing is leaving on purpose
    await userEvent.type(await screen.findByLabelText('Printer name'), ' left')
    await userEvent.click(screen.getByRole('button', { name: /Remove Printer/ }))
    expect(await screen.findByText('Remove Prusa MK4?')).toBeInTheDocument()
    expect(screen.getByText(/The printer itself is not touched/, { selector: '.ant-modal-body' })).toBeInTheDocument()
    await userEvent.click(screen.getAllByRole('button', { name: /Remove Printer/ }).at(-1))

    expect(await screen.findByText('Fleet list')).toBeInTheDocument()
    expect(router.state.location.pathname).toBe('/printers/manage')
    await waitFor(() => expect(cache.extract()['Printer:1']).toBeUndefined())
    // The page left before the printer was forgotten: its query didn't ask for the removed printer again
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(warn.mock.calls.flat().join()).not.toMatch(/No more mocked responses/)
    warn.mockRestore()
  })

  describe('with unsaved changes', () => {
    it('asks before following a link, and stays when asked to', async () => {
      const { router } = renderPage()
      await userEvent.type(await screen.findByLabelText('Printer name'), ' left')
      await userEvent.click(screen.getByRole('link', { name: /Printers/ }))
      expect(await screen.findByText('Leave without saving?')).toBeInTheDocument()

      await userEvent.click(screen.getByRole('button', { name: 'Keep Editing' }))
      expect(router.state.location.pathname).toBe('/printers/1')
      expect(field('Printer name')).toHaveValue('Prusa MK4 left')

      await userEvent.click(screen.getByRole('link', { name: /Printers/ }))
      await userEvent.click(await screen.findByRole('button', { name: 'Discard Changes' }))
      expect(await screen.findByText('Fleet list')).toBeInTheDocument()
    })

    it('makes the browser ask before closing the tab', async () => {
      renderPage()
      const closeTab = () => window.dispatchEvent(new Event('beforeunload', { cancelable: true }))
      await screen.findByLabelText('Printer name')
      expect(closeTab()).toBe(true)

      await userEvent.type(field('Printer name'), ' left')
      expect(closeTab()).toBe(false)
    })

    it('lets the page go without asking once nothing is unsaved', async () => {
      renderPage()
      await userEvent.click(await screen.findByRole('button', { name: 'Open Queue' }))
      expect(await screen.findByText('Queue')).toBeInTheDocument()
    })
  })
})
