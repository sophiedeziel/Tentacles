import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { GraphQLError } from 'graphql'
import { createMemoryRouter } from 'react-router'
import { RouterProvider } from 'react-router/dom'

import PrinterDetails from './PrinterDetails'
import { IDENTIFY_SAVED_PRINTER, PRINTER_DETAILS, PRINTER_VERSION, REPORTED_SPECS, UPDATE_PRINTER } from './graphql/details'
import { LOADED_FILAMENT, LOADED_FILAMENT_CHANGED } from './graphql/loadedFilament'
import { REMOVE_PRINTER, SET_PRINTER_FAVORITE } from '../PrintersList/graphql/fleet'
import { POSSIBLE_TYPES, PRINT_QUEUE_CHANGED, PRINTER_STATUS_CHANGED, TYPE_POLICIES } from '../../Dashboard/graphql/dashboard'
import { PRINTERS } from '../../Dashboard/widgets/Printer/fixtures'
import { GLOBAL_QUEUE_ENABLED, QUEUE_CHANGED } from '../../Queue/graphql/queue'
import { PRINTER_QUEUE, SET_PRINTER_TAKES_JOBS } from './graphql/printerQueue'
import { PLA_WHITE, printerQueue } from './printerQueueFixtures'

const { status } = PRINTERS.PRINTING
const NO_SPECS = {
  brand: null, model: null, firmwareDisplayName: null, firmwareVersion: null, buildVolume: null, extruders: null,
  nozzleDiameter: null, maxHotendTemp: null, maxBedTemp: null, heatedBed: null, heatedChamber: null, webcam: null, materials: []
}
const specs = (values = {}) => ({ __typename: 'PrinterSpecs', ...NO_SPECS, ...values })
const PRINTER = {
  __typename: 'Printer',
  ...PRINTERS.PRINTING,
  backend: 'PRUSALINK',
  uri: 'http://192.168.1.21',
  username: 'maker',
  favorite: false,
  specs: specs(),
  loadedFilaments: [],
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
// The Loaded Filament card's query (it selects the printer's materials too), with the printer's filaments
const filamentMock = ({ specs: { materials }, loadedFilaments }) => ({
  request: { query: LOADED_FILAMENT, variables: { printerId: '1' } },
  result: { data: { printer: { __typename: 'Printer', id: '1', specs: { __typename: 'PrinterSpecs', materials }, loadedFilaments }, filamentMaterials: ['PLA', 'PETG'], filamentColours: ['Black'] } }
})
const identify = (secret, result, options = {}) => ({
  request: {
    query: IDENTIFY_SAVED_PRINTER,
    variables: { backend: 'PRUSALINK', uri: 'http://192.168.1.21', username: 'maker', secret, printerId: '1' }
  },
  result,
  ...options
})
// What the server reports after the page renders: reportedSpecs, and the name identifyPrinter reads (by default: no
// answer, the printer is unreachable)
const reportedMocks = (reportedSpecs = null, name = null) => [
  { request: { query: REPORTED_SPECS, variables: { id: '1' } }, result: { data: { printer: { __typename: 'Printer', id: '1', reportedSpecs } } } },
  identify(null, name
    ? { data: { identifyPrinter: { __typename: 'PrinterIdentity', name, version: 'PrusaLink 2.1.2' } } }
    : { errors: [new GraphQLError('Could not reach PrusaLink', { extensions: { code: 'UNREACHABLE' } })] })
]
const PAGE_MOCKS = [
  { request: { query: PRINTER_DETAILS, variables: { id: '1' } }, result: { data: { printer: PRINTER } } },
  { request: { query: PRINTER_VERSION, variables: { id: '1' } }, result: { data: { printer: { __typename: 'Printer', id: '1', version: 'PrusaLink 2.1.2 (firmware 6.2.0)' } } } },
  { request: { query: PRINTER_STATUS_CHANGED }, result: { data: { printerStatusChanged: PRINTER } }, ...later },
  filamentMock(PRINTER),
  { request: { query: LOADED_FILAMENT_CHANGED }, result: { data: { printerStatusChanged: { __typename: 'Printer', id: '1', loadedFilaments: [] } } }, ...later },
  { request: { query: PRINT_QUEUE_CHANGED }, result: { data: { printQueueChanged: null } }, ...later },
  // The global queue is off
  { request: { query: GLOBAL_QUEUE_ENABLED }, result: { data: { globalQueue: null } } }
]
const BASE_MOCKS = [...PAGE_MOCKS, ...reportedMocks()]

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
  result: { data: { updatePrinter: { __typename: 'UpdatePrinterPayload', printer: { __typename: 'Printer', id: '1', name: PRINTER.name, uri: PRINTER.uri, username: 'maker', specs: PRINTER.specs, ...printer }, errors: [] } } }
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

  it('shows nothing of the global queue while it is off', async () => {
    renderPage()
    expect(await screen.findByRole('heading', { name: 'Loaded Filament' })).toBeInTheDocument()
    await screen.findByLabelText('Material')
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(screen.queryByRole('switch', { name: 'Taking jobs from the queue' })).not.toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Up Next for This Printer' })).not.toBeInTheDocument()
    expect(screen.queryByText(/remove the part/)).not.toBeInTheDocument()
    expect(screen.queryByText(/waiting job/)).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Printers/ })).toHaveAttribute('href', '/printers/manage')
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
    renderPage(
      [identify(null, { data: { identifyPrinter: { __typename: 'PrinterIdentity', name: 'Prusa MK4', version: 'PrusaLink 2.1.3' } } })],
      [...PAGE_MOCKS, ...reportedMocks(null, 'Prusa MK4')]
    )
    // The page's own read of the name is done: the test is a request of its own
    expect(await screen.findByText('From PrusaLink')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /Test Connection/ }))
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

  describe('Loaded Filament', () => {
    const fillInFilament = async () => {
      await userEvent.click(await screen.findByLabelText('Material'))
      await userEvent.click(await screen.findByTitle('PETG', { selector: '.ant-select-item-option' }))
      await userEvent.type(field('Colour'), 'Black')
    }

    it('is not part of the page\'s form: its edits leave Save Changes disabled and the page free to leave', async () => {
      renderPage()
      expect(await screen.findByRole('heading', { name: 'Loaded Filament' })).toBeInTheDocument()
      await fillInFilament()
      expect(screen.getByRole('button', { name: /Update Filament/ })).toBeEnabled()
      expect(screen.getByRole('button', { name: /Save Changes/ })).toBeDisabled()
      expect(window.dispatchEvent(new Event('beforeunload', { cancelable: true }))).toBe(true)
      await userEvent.click(screen.getByRole('button', { name: 'Open Queue' }))
      expect(await screen.findByText('Queue')).toBeInTheDocument()
    })

    it('submits nothing on Enter, even while the page\'s form has changes', async () => {
      renderPage([updated({ name: 'Prusa MK4 left' }, { name: 'Prusa MK4 left' })])
      await userEvent.type(await screen.findByLabelText('Printer name'), ' left')
      await fillInFilament()
      await userEvent.type(field('Colour'), '{Enter}')
      await new Promise((resolve) => setTimeout(resolve, 50))
      expect(screen.queryByText('Changes saved')).not.toBeInTheDocument()
      expect(screen.queryByText(/Could not save/)).not.toBeInTheDocument()

      // Where Enter does submit the page's form
      await userEvent.type(field('Printer name'), '{Enter}')
      expect(await screen.findByText('Changes saved')).toBeInTheDocument()
    })
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

  describe('About This Printer', () => {
    const MK4_SPECS = {
      brand: 'Prusa Research',
      model: 'MK4',
      firmwareDisplayName: 'prusa_firmware',
      firmwareVersion: '6.2.0',
      buildVolume: { __typename: 'RectangularBuildVolume', x: 250, y: 210, z: 220 },
      nozzleDiameter: 0.6,
      materials: ['PLA', 'PETG']
    }
    // The page of a printer with these specs, and what its server reports
    const renderAbout = (saved, mocks = [], { reported = null, name = null } = {}) => {
      const printer = { ...PRINTER, specs: specs(saved) }
      return renderPage(mocks, [
        { ...PAGE_MOCKS[0], result: { data: { printer } } },
        ...PAGE_MOCKS.slice(1).map((mock) => (mock.request.query === LOADED_FILAMENT ? filamentMock(printer) : mock)),
        ...reportedMocks(reported && specs(reported), name)
      ])
    }
    const savedSpecs = (input, saved) => updated({ specs: input }, { specs: specs(saved) })
    const volume = (label) => within(screen.getByRole('group', { name: 'Build volume' })).getByLabelText(label)
    const pick = async (label, option) => {
      await userEvent.click(field(label))
      await userEvent.click(await screen.findByTitle(option, { selector: '.ant-select-item-option' }))
    }

    it('shows the saved specs, with no reload button while the server reports nothing', async () => {
      renderAbout(MK4_SPECS)
      expect(await screen.findByRole('heading', { name: 'About This Printer' })).toBeInTheDocument()
      expect(screen.getByText('PrusaLink can fill in some of these fields')).toBeInTheDocument()
      expect(screen.getByText(
        'Empty fields are filled in from PrusaLink when Tentacles first reaches the printer, and again when its ' +
        'address changes. A field that already has a value is never replaced, unless you click the reload icon next ' +
        'to it, and that reloads only that field.'
      )).toBeInTheDocument()
      expect(field('Brand')).toHaveValue('Prusa Research')
      expect(screen.getByText('Printer servers do not report a brand.')).toBeInTheDocument()
      expect(screen.getByTitle('Prusa Firmware')).toBeInTheDocument()
      expect(volume('Width (X)')).toHaveValue('250')
      expect(volume('Height (Z)')).toHaveValue('220')
      expect(screen.getByText('PrusaLink cameras are not read yet')).toBeInTheDocument()
      expect(screen.getByTitle('PETG')).toBeInTheDocument()
      expect(screen.queryByRole('button', { name: /Reload/ })).not.toBeInTheDocument()
      expect(screen.getByRole('button', { name: /Save Changes/ })).toBeDisabled()
    })

    it('switches the build volume to Diameter and Z for a circular bed', async () => {
      renderAbout(MK4_SPECS, [savedSpecs(
        { buildVolume: { circular: { diameter: 180, height: 220 } } },
        { ...MK4_SPECS, buildVolume: { __typename: 'CircularBuildVolume', diameter: 180, height: 220 } }
      )])
      await screen.findByRole('heading', { name: 'About This Printer' })
      await pick('Bed shape', 'Circular')
      expect(volume('Diameter')).toBeVisible()
      expect(volume('Width (X)')).not.toBeVisible()
      // Z carries over; the diameter is missing
      expect(screen.getByText(/Fill in every dimension/)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /Save Changes/ })).toBeDisabled()

      await userEvent.type(volume('Diameter'), '180')
      await save()
      expect(await screen.findByText('Changes saved')).toBeInTheDocument()
      expect(volume('Diameter')).toHaveValue('180')
    })

    it('clears the build volume once all of its dimensions are cleared', async () => {
      renderAbout(MK4_SPECS, [savedSpecs({ buildVolume: null }, { ...MK4_SPECS, buildVolume: null })])
      await screen.findByRole('heading', { name: 'About This Printer' })
      for (const label of ['Width (X)', 'Depth (Y)', 'Height (Z)']) await userEvent.clear(volume(label))
      await save()
      expect(await screen.findByText('Changes saved')).toBeInTheDocument()
    })

    it('takes a firmware that is not in the list, as typed', async () => {
      renderAbout(MK4_SPECS, [savedSpecs({ firmware: 'Smoothie' }, { ...MK4_SPECS, firmwareDisplayName: 'Smoothie' })])
      await screen.findByRole('heading', { name: 'About This Printer' })
      await userEvent.type(field('Firmware'), 'Smoothie')
      await userEvent.click(await screen.findByTitle('Smoothie', { selector: '.ant-select-item-option' }))
      await save()
      expect(await screen.findByText('Changes saved')).toBeInTheDocument()
      expect(field('Firmware').closest('.ant-select')).toHaveTextContent('Smoothie')
    })

    it('starts empty for a printer without specs', async () => {
      renderAbout({}, [savedSpecs({ model: 'Ender 5 Plus', materials: ['PLA'] }, { model: 'Ender 5 Plus', materials: ['PLA'] })])
      await screen.findByRole('heading', { name: 'About This Printer' })
      expect(field('Model')).toHaveValue('')
      expect(volume('Width (X)')).toHaveValue('')
      await userEvent.type(field('Model'), 'Ender 5 Plus')
      await pick('Materials', 'PLA')
      await save()
      expect(await screen.findByText('Changes saved')).toBeInTheDocument()
    })

    it('shows what the server reports, and reloads one field into the form', async () => {
      const reported = { model: 'MK4', firmwareDisplayName: 'prusa_firmware', firmwareVersion: '6.2.1', nozzleDiameter: 0.4, materials: [] }
      renderAbout(MK4_SPECS, [savedSpecs({ nozzleDiameter: 0.4 }, { ...MK4_SPECS, nozzleDiameter: 0.4 })], { reported, name: 'MK4 #2' })
      expect(await screen.findByText('PrusaLink reports 0.4 mm')).toBeInTheDocument()
      expect(screen.getByText('PrusaLink reports 6.2.1')).toBeInTheDocument()
      expect(await screen.findByText('PrusaLink reports MK4 #2')).toBeInTheDocument()
      expect(screen.getAllByText('From PrusaLink')).toHaveLength(2) // model, firmware
      expect(screen.queryByRole('button', { name: 'Reload build volume from PrusaLink' })).not.toBeInTheDocument()

      await userEvent.click(screen.getByRole('button', { name: 'Reload nozzle diameter from PrusaLink' }))
      expect(field('Nozzle diameter')).toHaveValue('0.4')
      expect(screen.getAllByText('From PrusaLink')).toHaveLength(3)
      // Only that field: Save Changes writes it
      expect(field('Firmware version')).toHaveValue('6.2.0')
      expect(field('Printer name')).toHaveValue('Prusa MK4')
      await save()
      expect(await screen.findByText('Changes saved')).toBeInTheDocument()
    })

    it('still shows the name\'s error beside its reload button', async () => {
      renderAbout(MK4_SPECS, [], { name: 'MK4 #2' })
      expect(await screen.findByText('PrusaLink reports MK4 #2')).toBeInTheDocument()
      await userEvent.clear(field('Printer name'))
      await save()
      expect(await screen.findByText('Name is required')).toBeInTheDocument()
    })

    it('reloads the name identifyPrinter reads', async () => {
      renderAbout(MK4_SPECS, [], { name: 'MK4 #2' })
      await userEvent.click(await screen.findByRole('button', { name: 'Reload printer name from PrusaLink' }))
      expect(field('Printer name')).toHaveValue('MK4 #2')
      expect(screen.getByRole('button', { name: /Save Changes/ })).toBeEnabled()
    })

  })
})

describe('PrinterDetails with the global queue on', () => {
  const printer = { ...PRINTER, loadedFilaments: [{ ...PLA_WHITE, updatedAt: '2026-11-20T12:00:00Z' }] }
  const queueAnswer = (answer) => ({ request: { query: PRINTER_QUEUE, variables: { id: '1' } }, result: { data: answer } })
  // The page of a printer with PLA White loaded (in every query that selects it), the queue on. `queueAnswers`: what
  // the printer's queue query answers, in turn. `enabledDelay`: how late the check whether the queue is on answers.
  const renderOn = (queueAnswers = [printerQueue()], mocks = [], { enabledDelay = 0 } = {}) => renderPage(mocks, [
    { ...PAGE_MOCKS[0], result: { data: { printer } } },
    ...PAGE_MOCKS.slice(1, -1).map((mock) => (mock.request.query === LOADED_FILAMENT ? filamentMock(printer) : mock)),
    {
      request: { query: GLOBAL_QUEUE_ENABLED },
      result: { data: { globalQueue: { __typename: 'GlobalQueue', dispatchPaused: false } } },
      delay: enabledDelay
    },
    { request: { query: QUEUE_CHANGED }, result: { data: { queueChanged: { __typename: 'QueueChange', dispatchPaused: false } } }, ...later },
    ...queueAnswers.map(queueAnswer),
    ...reportedMocks()
  ])

  it('follows the PrinterQueue frame: back to the queue, the switch, the bed banner, then the lists beside the cards', async () => {
    renderOn()

    const upNext = await screen.findByRole('region', { name: 'Up Next for This Printer' })
    expect(screen.getByRole('link', { name: /Print Queue/ })).toHaveAttribute('href', '/queue')
    expect(screen.getByRole('switch', { name: 'Taking jobs from the queue' })).toBeChecked()
    const banner = screen.getByRole('region', { name: 'Print finished: remove the part' })
    expect(banner).toHaveTextContent('bracket.gcode · copy 2 of 10 is done.')
    const skipped = screen.getByRole('region', { name: 'Skipped by This Printer' })

    // The header, the banner, Up Next and Skipped, then Connection under them; Loaded Filament and About This
    // Printer in the other column
    const follows = (a, b) => Boolean(a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING)
    const header = screen.getByRole('heading', { name: 'Prusa MK4' })
    const connection = screen.getByRole('heading', { name: 'Connection' })
    const filament = screen.getByRole('heading', { name: 'Loaded Filament' })
    const about = screen.getByRole('heading', { name: 'About This Printer' })
    expect(follows(header, banner) && follows(banner, upNext) && follows(upNext, skipped)).toBe(true)
    expect(follows(skipped, connection) && follows(connection, filament) && follows(filament, about)).toBe(true)

    expect(await screen.findByText('No waiting job asks for PLA White. Any Colour jobs still match.')).toBeInTheDocument()
    expect(screen.getByText('Set this when you swap spools. The queue matches jobs against it.')).toBeInTheDocument()
  })

  it('saves Takes Jobs apart from the page\'s form, which it never submits', async () => {
    const sent = []
    renderOn([printerQueue(), printerQueue({ ...printerQueue().printer, takesJobs: false })], [{
      request: { query: SET_PRINTER_TAKES_JOBS, variables: { printerId: '1', takesJobs: false } },
      result: () => {
        sent.push({ printerId: '1', takesJobs: false })
        return {
          data: {
            setPrinterTakesJobs: {
              __typename: 'SetPrinterTakesJobsPayload', success: true, errors: [], printer: { __typename: 'Printer', id: '1', takesJobs: false }
            }
          }
        }
      }
    }])
    await userEvent.type(await screen.findByLabelText('Printer name'), ' left')
    await userEvent.click(await screen.findByRole('switch', { name: 'Taking jobs from the queue' }))

    await waitFor(() => expect(sent).toEqual([{ printerId: '1', takesJobs: false }]))
    await waitFor(() => expect(screen.getByRole('switch', { name: 'Not taking jobs' })).not.toBeChecked())
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(screen.queryByText('Changes saved')).not.toBeInTheDocument()
    expect(screen.queryByText(/Could not save/)).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Save Changes/ })).toBeEnabled()
  })

  it('shows the form once it knows the queue is on, so its fields never move under the person typing', async () => {
    // The printer answers first: shown in the layout for the queue off, the form would then move to the queue's,
    // remounting the field being typed in
    renderOn(undefined, [], { enabledDelay: 100 })
    const name = await screen.findByLabelText('Printer name')
    expect(screen.getByRole('link', { name: /Print Queue/ })).toBeInTheDocument()

    await userEvent.type(name, ' left')
    expect(await screen.findByRole('region', { name: 'Up Next for This Printer' })).toBeInTheDocument()
    expect(name.isConnected).toBe(true)
    expect(field('Printer name')).toHaveValue('Prusa MK4 left')
    expect(screen.getByRole('button', { name: /Save Changes/ })).toBeEnabled()
  })
})
