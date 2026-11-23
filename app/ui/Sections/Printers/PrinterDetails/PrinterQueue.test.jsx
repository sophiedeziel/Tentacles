import React from 'react'
import PropTypes from 'prop-types'
import { describe, expect, it, vi } from 'vitest'
import { act, render, renderHook, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { ApolloClient, ApolloLink, InMemoryCache } from '@apollo/client'
import { ApolloProvider } from '@apollo/client/react'
import { MemoryRouter } from 'react-router'
import { App } from 'antd'
import { Observable } from 'rxjs'

import { BedBanner, Skipped, TakesJobsSwitch, UpNext } from './PrinterQueue'
import usePrinterQueue from './usePrinterQueue'
import { SET_PRINTER_TAKES_JOBS } from './graphql/printerQueue'
import { printOnBed, printerQueue, queuePrinter } from './printerQueueFixtures'
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

// The parts as the page places them: the switch, the bed banner while there is a bed to clear, Up Next and Skipped
function Parts ({ printer, dispatchPaused, reload }) {
  return (
    <>
      <TakesJobsSwitch printer={printer} reload={reload} />
      {printer.bedNeedsClearing && <BedBanner printer={printer} dispatchPaused={dispatchPaused} reload={reload} />}
      <UpNext printer={printer} reload={reload} />
      <Skipped rows={printer.skipped} />
    </>
  )
}

Parts.propTypes = {
  printer: PropTypes.shape({
    bedNeedsClearing: PropTypes.bool.isRequired,
    skipped: PropTypes.array.isRequired
  }).isRequired,
  dispatchPaused: PropTypes.bool.isRequired,
  reload: PropTypes.func.isRequired
}

const renderQueue = (printer = queuePrinter(), { mocks = [], dispatchPaused = false } = {}) => {
  const reload = vi.fn(() => Promise.resolve())
  render(
    <MockedProvider cache={new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })} mocks={mocks}>
      <MemoryRouter>
        <App><Parts printer={printer} dispatchPaused={dispatchPaused} reload={reload} /></App>
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
    it('names the copy on the bed, and confirms Bed Cleared in the queue page\'s modal with what is next for it', async () => {
      const confirm = mutation(CONFIRM_BED_CLEARED, 'confirmBedCleared', { printerId: '1' })
      const { reload } = renderQueue(queuePrinter(), { mocks: [confirm.mock] })

      const banner = section('Print finished: remove the part')
      expect(banner).toHaveTextContent(
        'bracket.gcode · copy 2 of 10 is done. This printer takes no new job until you confirm the bed is clear.'
      )

      await userEvent.click(within(banner).getByRole('button', { name: 'Bed Cleared' }))
      const dialog = await screen.findByRole('dialog')
      expect(dialog).toHaveTextContent('Is the bed of Prusa MK4 clear?')
      expect(dialog).toHaveTextContent(
        'It starts printing as soon as it can pick a job from the queue. Next for it: cable_clip.gcode, copy 3 of 3.'
      )
      expect(dialog).toHaveTextContent('Check that the part and any leftover filament are off the bed first.')

      await userEvent.click(within(dialog).getByRole('button', { name: 'Bed Is Clear' }))
      await waitFor(() => expect(confirm.sent).toEqual([{ printerId: '1' }]))
      await waitFor(() => expect(reload).toHaveBeenCalled())
    })

    it('says how the print ended, and what a printer not taking jobs does next', async () => {
      renderQueue(queuePrinter({ printOnBed: printOnBed('FAILED'), takesJobs: false }), { dispatchPaused: true })

      expect(section('Print failed: remove the part')).toHaveTextContent('bracket.gcode · copy 2 of 10 failed.')
      await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
      const dialog = await screen.findByRole('dialog')
      expect(dialog).toHaveTextContent("Prusa MK4 isn't taking jobs from the queue, so it won't start the next one.")
    })

    it('says the last print when it does not know which', () => {
      renderQueue(queuePrinter({ printOnBed: null }))
      expect(section('Remove the last print'))
        .toHaveTextContent('This printer takes no new job until you confirm the bed is clear.')
    })

    it('is not shown once the bed is clear', () => {
      renderQueue(queuePrinter({ bedNeedsClearing: false, printOnBed: null }))
      expect(screen.queryByRole('button', { name: 'Bed Cleared' })).not.toBeInTheDocument()
      expect(screen.queryByRole('region', { name: /remove/ })).not.toBeInTheDocument()
    })
  })

  describe('Taking jobs from the queue', () => {
    it('saves the switch at once, then reloads', async () => {
      const saved = mutation(SET_PRINTER_TAKES_JOBS, 'setPrinterTakesJobs', { printerId: '1', takesJobs: false }, {
        payload: { printer: { __typename: 'Printer', id: '1', takesJobs: false } }
      })
      const { reload } = renderQueue(queuePrinter(), { mocks: [saved.mock] })

      const toggle = screen.getByRole('switch', { name: 'Taking jobs from the queue' })
      expect(toggle).toBeChecked()

      await userEvent.click(toggle)
      await waitFor(() => expect(saved.sent).toEqual([{ printerId: '1', takesJobs: false }]))
      await waitFor(() => expect(reload).toHaveBeenCalled())
    })

    it('flips from its words too', async () => {
      const saved = mutation(SET_PRINTER_TAKES_JOBS, 'setPrinterTakesJobs', { printerId: '1', takesJobs: false }, {
        payload: { printer: { __typename: 'Printer', id: '1', takesJobs: false } }
      })
      renderQueue(queuePrinter(), { mocks: [saved.mock] })

      await userEvent.click(screen.getByText('Taking jobs from the queue'))
      await waitFor(() => expect(saved.sent).toEqual([{ printerId: '1', takesJobs: false }]))
    })

    it('shows why the server refused', async () => {
      const saved = mutation(SET_PRINTER_TAKES_JOBS, 'setPrinterTakesJobs', { printerId: '1', takesJobs: true }, {
        payload: { printer: { __typename: 'Printer', id: '1', takesJobs: false } },
        errors: refused('The global print queue is off')
      })
      renderQueue(queuePrinter({ takesJobs: false }), { mocks: [saved.mock] })

      await userEvent.click(screen.getByRole('switch', { name: 'Not taking jobs' }))
      expect(await screen.findByText('The global print queue is off')).toBeInTheDocument()
      expect(screen.getByRole('switch', { name: 'Not taking jobs' })).not.toBeChecked()
    })
  })

  describe('Up Next for This Printer', () => {
    it('lists the waiting jobs it can take, with their place in the queue, size, needs and what happens next', () => {
      renderQueue()

      expect(section('Up Next for This Printer')).toHaveTextContent('In queue order, jobs it qualifies for')
      expect(within(section('Up Next for This Printer')).queryAllByRole('columnheader')).toHaveLength(0)
      expect(rows('Up Next for This Printer').map((each) => within(each).getAllByRole('cell')[0].textContent))
        .toEqual(['#1', '#2', '#4'])

      const single = row('Up Next for This Printer', '11')
      expect(within(single).getByText('phone_stand.gcode')).toBeInTheDocument()
      expect(within(single).getByText('1 print')).toBeInTheDocument()
      expect(within(single).getByText('PLA · Black')).toBeInTheDocument()
      expect(within(single).getByText('Prusa Mini+ takes it once its bed is cleared')).toBeInTheDocument()
      expect(within(single).queryByText('Same printer')).not.toBeInTheDocument()

      const batch = row('Up Next for This Printer', '12')
      expect(within(batch).getByText('Batch of 3 · 1 left to start')).toBeInTheDocument()
      expect(within(batch).getByText('Same printer')).toBeInTheDocument()
      expect(within(batch).getByText('T0 PETG · Any colour')).toBeInTheDocument()
      expect(within(batch).getByText('T1 PLA · Any colour')).toBeInTheDocument()
      // Its own printer: said from this page
      expect(within(batch).getByText('Prints copy 3 when copy 2 finishes')).toBeInTheDocument()
    })

    it('highlights the job it takes next', () => {
      renderQueue()
      expect(row('Up Next for This Printer', '12').style.background).not.toBe('')
      expect(row('Up Next for This Printer', '11').style.background).toBe('')
    })

    it('highlights nothing when it takes nothing next', () => {
      renderQueue(queuePrinter({ takesNext: null }))
      rows('Up Next for This Printer').forEach((each) => expect(each.style.background).toBe(''))
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
    it('lists the jobs it skips and how many, each reason on its own line', () => {
      renderQueue()

      expect(section('Skipped by This Printer')).toHaveTextContent("1 job it can't take, and why")
      const skipped = row('Skipped by This Printer', '15')
      const cells = within(skipped).getAllByRole('cell')
      expect(cells[0]).toHaveTextContent('#3')
      expect(cells[1]).toHaveTextContent('vase.gcode')
      expect(within(cells[2]).getByText('Limited to Voron 2.4')).toBeInTheDocument()
      expect(within(cells[2]).getByText('Needs PETG. PLA is loaded here')).toBeInTheDocument()
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
