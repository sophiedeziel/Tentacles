import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { act, render, renderHook, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { ApolloClient, ApolloLink, InMemoryCache } from '@apollo/client'
import { ApolloProvider } from '@apollo/client/react'
import { MemoryRouter } from 'react-router'
import { App } from 'antd'
import { Observable } from 'rxjs'

import PrinterQueue from './PrinterQueue'
import usePrinterQueue from './usePrinterQueue'
import { SET_PRINTER_TAKES_JOBS } from './graphql/printerQueue'
import { printerQueue, queuePrinter } from './printerQueueFixtures'
import { CONFIRM_BED_CLEARED, RELEASE_PRINT_JOB } from '../../Queue/graphql/actions'
import { REFETCH_DELAY } from '../../Queue/useGlobalQueue'
import { POSSIBLE_TYPES, TYPE_POLICIES } from '../../Dashboard/graphql/dashboard'

const refused = (message) => [{ __typename: 'UserError', field: null, message }]

// A mutation the server answers: `sent` lists the variables of each request. `payload` completes the answer; `errors`
// makes it a refusal.
function mutation (query, field, variables, { payload = {}, errors = [] } = {}) {
  const sent = []
  const mock = {
    request: { query, variables },
    result: () => {
      sent.push(variables)
      return { data: { [field]: { __typename: 'Payload', success: errors.length === 0, errors, ...payload } } }
    }
  }
  return { sent, mock }
}

const renderQueue = (printer = queuePrinter(), { mocks = [], dispatchPaused = false } = {}) => {
  const reload = vi.fn(() => Promise.resolve())
  render(
    <MockedProvider cache={new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })} mocks={mocks}>
      <MemoryRouter>
        <App><PrinterQueue printer={printer} dispatchPaused={dispatchPaused} reload={reload} /></App>
      </MemoryRouter>
    </MockedProvider>
  )
  return { reload }
}

const section = (name) => screen.getByRole('region', { name })
// The body rows of a section's table (antd adds a hidden measure row)
const rows = (name) => within(section(name)).getAllByRole('row').filter((row) => row.dataset.rowKey)
const row = (name, key) => rows(name).find((each) => each.dataset.rowKey === key)

describe('PrinterQueue', () => {
  describe('the bed banner', () => {
    it('names the print on the bed, and confirms Bed Cleared in the queue page\'s modal', async () => {
      const confirm = mutation(CONFIRM_BED_CLEARED, 'confirmBedCleared', { printerId: '1' })
      const { reload } = renderQueue(queuePrinter(), { mocks: [confirm.mock] })

      const banner = screen.getByRole('alert')
      expect(banner).toHaveTextContent('bracket.gcode is still on the bed')
      expect(banner).toHaveTextContent('Clear it, then confirm: Prusa MK4 takes no job from the queue until then.')

      await userEvent.click(within(banner).getByRole('button', { name: 'Bed Cleared' }))
      const dialog = await screen.findByRole('dialog')
      expect(dialog).toHaveTextContent('Is the bed of Prusa MK4 clear?')
      expect(dialog).toHaveTextContent('It starts printing as soon as it can pick a job from the queue.')
      expect(dialog).toHaveTextContent('Check that the part and any leftover filament are off the bed first.')

      await userEvent.click(within(dialog).getByRole('button', { name: 'Bed Is Clear' }))
      await waitFor(() => expect(confirm.sent).toEqual([{ printerId: '1' }]))
      await waitFor(() => expect(reload).toHaveBeenCalled())
    })

    it('says the last print when it does not know which, and what a printer not taking jobs does next', async () => {
      renderQueue(queuePrinter({ printOnBed: null, takesJobs: false }), { dispatchPaused: true })

      expect(screen.getByRole('alert')).toHaveTextContent('The last print is still on the bed')
      await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
      const dialog = await screen.findByRole('dialog')
      expect(dialog).toHaveTextContent("Prusa MK4 isn't taking jobs from the queue, so it won't start the next one.")
    })

    it('is not shown once the bed is clear', () => {
      renderQueue(queuePrinter({ bedNeedsClearing: false, printOnBed: null }))
      expect(screen.queryByRole('alert')).not.toBeInTheDocument()
    })
  })

  describe('Takes Jobs', () => {
    it('saves the switch at once, then reloads', async () => {
      const saved = mutation(SET_PRINTER_TAKES_JOBS, 'setPrinterTakesJobs', { printerId: '1', takesJobs: false }, {
        payload: { printer: { __typename: 'Printer', id: '1', takesJobs: false } }
      })
      const { reload } = renderQueue(queuePrinter(), { mocks: [saved.mock] })

      expect(screen.getByRole('region', { name: 'Takes Jobs' }))
        .toHaveTextContent('When off, the queue skips this printer: nothing new starts on it. A print under way goes on.')
      const toggle = screen.getByRole('switch', { name: 'Takes jobs' })
      expect(toggle).toBeChecked()

      await userEvent.click(toggle)
      await waitFor(() => expect(saved.sent).toEqual([{ printerId: '1', takesJobs: false }]))
      await waitFor(() => expect(reload).toHaveBeenCalled())
    })

    it('shows why the server refused', async () => {
      const saved = mutation(SET_PRINTER_TAKES_JOBS, 'setPrinterTakesJobs', { printerId: '1', takesJobs: true }, {
        payload: { printer: { __typename: 'Printer', id: '1', takesJobs: false } },
        errors: refused('The global print queue is off')
      })
      renderQueue(queuePrinter({ takesJobs: false }), { mocks: [saved.mock] })

      await userEvent.click(screen.getByRole('switch', { name: 'Takes jobs' }))
      expect(await screen.findByText('The global print queue is off')).toBeInTheDocument()
      expect(screen.getByRole('switch', { name: 'Takes jobs' })).not.toBeChecked()
    })
  })

  describe('Up Next for This Printer', () => {
    it('lists the waiting jobs it can take, with their place in the queue, needs and what happens next', () => {
      renderQueue()

      expect(within(section('Up Next for This Printer')).getByText('3')).toBeInTheDocument()
      expect(rows('Up Next for This Printer').map((each) => within(each).getAllByRole('cell')[0].textContent))
        .toEqual(['1', '2', '4'])

      const single = row('Up Next for This Printer', '11')
      expect(within(single).getByRole('link', { name: 'phone_stand.gcode' })).toHaveAttribute('href', '/files/20')
      expect(within(single).getByText('PLA · Black')).toBeInTheDocument()
      expect(within(single).getByText('120 × 80 mm')).toBeInTheDocument()
      expect(within(single).getByText('Prusa Mini+ takes it once its bed is cleared')).toBeInTheDocument()
      expect(within(single).queryByText('Same printer')).not.toBeInTheDocument()

      const batch = row('Up Next for This Printer', '12')
      expect(within(batch).getByText('× 3 · 1 left to start')).toBeInTheDocument()
      expect(within(batch).getByText('Same printer')).toBeInTheDocument()
      expect(within(batch).getByText('T0 PETG · Any colour')).toBeInTheDocument()
      // Its own printer: said from this page
      expect(within(batch).getByText('Prints copy 3 when copy 2 finishes')).toBeInTheDocument()
    })

    it('says a held job is on hold until released, and releases it', async () => {
      const released = mutation(RELEASE_PRINT_JOB, 'releasePrintJob', { id: '13' }, { payload: { printJob: null } })
      const { reload } = renderQueue(queuePrinter(), { mocks: [released.mock] })

      const held = row('Up Next for This Printer', '13')
      expect(within(held).getByText('On hold until released')).toBeInTheDocument()
      await userEvent.click(within(held).getByRole('button', { name: 'Release' }))
      await waitFor(() => expect(released.sent).toEqual([{ id: '13' }]))
      await waitFor(() => expect(reload).toHaveBeenCalled())
    })

    it('says when no waiting job is for this printer', () => {
      renderQueue(queuePrinter({ upNext: [] }))
      expect(within(section('Up Next for This Printer')).getByText('No waiting job for this printer')).toBeInTheDocument()
    })
  })

  describe('Skipped by This Printer', () => {
    it('lists the jobs it skips, each reason on its own line', () => {
      renderQueue()

      const skipped = row('Skipped by This Printer', '15')
      const cells = within(skipped).getAllByRole('cell')
      expect(cells[0]).toHaveTextContent('3')
      expect(within(skipped).getByRole('link', { name: 'vase.gcode' })).toBeInTheDocument()
      expect(within(cells[2]).getByText('Limited to Voron 2.4')).toBeInTheDocument()
      expect(within(cells[2]).getByText('Needs PETG, PLA is loaded here')).toBeInTheDocument()
    })

    it('is not shown when it skips nothing', () => {
      renderQueue(queuePrinter({ skipped: [] }))
      expect(screen.queryByRole('region', { name: 'Skipped by This Printer' })).not.toBeInTheDocument()
    })
  })
})

// A server that counts the page's queue requests and pushes queueChanged when told to
function fakeServer () {
  const server = { requests: 0, push: null }
  server.link = new ApolloLink((operation) => new Observable((observer) => {
    if (operation.operationName === 'PrinterDetailsQueue') {
      server.requests += 1
      observer.next({ data: printerQueue() })
      observer.complete()
    } else if (operation.operationName === 'GlobalQueueChanged') {
      server.push = () => observer.next({
        data: { queueChanged: { __typename: 'QueueChange', dispatchPaused: false } }
      })
    }
  }))
  return server
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

describe('usePrinterQueue', () => {
  const renderQueueHook = (server, enabled) => {
    const client = new ApolloClient({
      link: server.link,
      cache: new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })
    })
    return renderHook(() => usePrinterQueue('1', { enabled }), {
      wrapper: ({ children }) => <ApolloProvider client={client}>{children}</ApolloProvider>
    })
  }

  it('loads the printer\'s queue, then reloads it once per burst of queueChanged pushes', async () => {
    const server = fakeServer()
    const { result } = renderQueueHook(server, true)

    await waitFor(() => expect(result.current.loaded).toBe(true))
    await waitFor(() => expect(server.push).not.toBeNull())
    expect(result.current.printer.upNext).toHaveLength(3)
    expect(result.current.dispatchPaused).toBe(false)
    expect(server.requests).toBe(1)

    act(() => {
      server.push()
      server.push()
      server.push()
    })
    await wait(REFETCH_DELAY / 2)
    expect(server.requests).toBe(1)

    await waitFor(() => expect(server.requests).toBe(2))
    await wait(REFETCH_DELAY * 2)
    expect(server.requests).toBe(2)
  })

  it('asks nothing while the global queue is off', async () => {
    const server = fakeServer()
    const { result } = renderQueueHook(server, false)

    await result.current.reload()
    await wait(50)
    expect(server.requests).toBe(0)
    expect(server.push).toBeNull()
    expect(result.current).toMatchObject({ printer: null, loaded: false, dispatchPaused: false })
  })
})
