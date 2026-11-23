import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { MemoryRouter } from 'react-router'

import QueuePage from './QueuePage'
import { FINISHED_ROWS, GLOBAL_QUEUE_PAGE, QUEUE_CHANGED } from './graphql/queue'
import { POSSIBLE_TYPES, PRINT_QUEUE_CHANGED, PRINTER_STATUS_CHANGED, TYPE_POLICIES } from '../Dashboard/graphql/dashboard'
import { BATCH, EMPTY_QUEUE, HELD, MINI, MK4, VORON_ZERO, queue, waitingJob, whatHappensNext } from './fixtures'

const later = { delay: 60000 }

const renderPage = (globalQueue) => render(
  <MockedProvider cache={new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })} mocks={[
    { request: { query: GLOBAL_QUEUE_PAGE, variables: { finished: FINISHED_ROWS } }, result: { data: { globalQueue } } },
    { request: { query: PRINTER_STATUS_CHANGED }, result: { data: { printerStatusChanged: MK4 } }, ...later },
    { request: { query: PRINT_QUEUE_CHANGED }, result: { data: { printQueueChanged: null } }, ...later },
    { request: { query: QUEUE_CHANGED }, result: { data: { queueChanged: { __typename: 'QueueChange', dispatchPaused: false } } }, ...later }
  ]}>
    <MemoryRouter initialEntries={['/queue']}><QueuePage /></MemoryRouter>
  </MockedProvider>
)

const loadPage = async (globalQueue) => {
  renderPage(globalQueue)
  await screen.findByRole('heading', { name: 'Print Queue' })
}

const section = (name) => screen.getByRole('region', { name })
// The body rows of a section's table (antd adds a hidden measure row)
const rows = (name) => within(section(name)).getAllByRole('row').filter((row) => row.dataset.rowKey)
const row = (name, key) => rows(name).find((each) => each.dataset.rowKey === key)
const blocked = (eligiblePrinters) => waitingJob({ id: '15', eligiblePrinters, whatHappensNext: whatHappensNext('BLOCKED') })

describe('QueuePage', () => {
  it('shows the four sections in order', async () => {
    await loadPage(queue())

    expect(screen.getAllByRole('region').map((region) => region.getAttribute('aria-label'))).toEqual([
      'Available Printers', 'Printing', 'Waiting', 'Finished'
    ])
    expect(screen.getByText(/One queue for every printer/)).toBeInTheDocument()
  })

  it('lists a printer with its bed to clear first, with what it takes next and what is on its bed', async () => {
    await loadPage(queue())

    expect(rows('Available Printers').map((each) => each.dataset.rowKey)).toEqual([MINI.id, VORON_ZERO.id])
    expect(within(section('Available Printers')).getByText('2 printers free to take a job')).toBeInTheDocument()
    const toClear = row('Available Printers', MINI.id)
    expect(within(toClear).getByRole('link', { name: 'Prusa Mini+' })).toHaveAttribute('href', '/printers/4')
    expect(within(toClear).getByText('Operational')).toBeInTheDocument()
    expect(within(toClear).getByText('PLA · Black')).toBeInTheDocument()
    expect(within(toClear).getByText('phone_stand.gcode, once its bed is cleared')).toBeInTheDocument()
    expect(within(toClear).getByText('bracket.gcode failed and is still on the bed')).toBeInTheDocument()
    expect(toClear.style.background).not.toBe('')
  })

  it('lists the free printers after, then the offline ones', async () => {
    await loadPage(queue())

    const free = row('Available Printers', VORON_ZERO.id)
    expect(within(free).getByText('Nothing waiting it can print')).toBeInTheDocument()
    expect(free.style.background).toBe('')
    expect(within(section('Available Printers')).getByText('Kobra 2 is offline and takes no jobs.')).toBeInTheDocument()
  })

  it('shows the copies printing, with the progress their printer reports', async () => {
    await loadPage(queue())

    expect(within(section('Printing')).getByText('1 print under way')).toBeInTheDocument()
    const printing = row('Printing', '32')
    expect(within(printing).getByText('cable_clip.gcode')).toBeInTheDocument()
    expect(within(printing).getByText('Copy 2 of 3')).toBeInTheDocument()
    expect(within(printing).getByRole('link', { name: 'Prusa MK4' })).toHaveAttribute('href', '/printers/1')
    expect(within(printing).getByText('PETG · Grey')).toBeInTheDocument()
    expect(within(printing).getByText('Printing')).toBeInTheDocument()
    // The printer's status says 64%, the print as last saved 40%: the live status wins
    expect(within(printing).getByText('64%')).toBeInTheDocument()
  })

  it('shows the waiting jobs in queue order, with their needs, printers and what happens next', async () => {
    await loadPage(queue())

    expect(within(section('Waiting')).getByText('3 jobs · 3 prints')).toBeInTheDocument()
    expect(rows('Waiting').map((each) => within(each).getAllByRole('cell')[0].textContent)).toEqual(['1', '2', '3'])

    const single = row('Waiting', '11')
    expect(within(single).getByText('phone_stand.gcode')).toBeInTheDocument()
    expect(within(single).getByText('1 print')).toBeInTheDocument()
    expect(within(single).getByText('PLA · Black')).toBeInTheDocument()
    expect(within(single).getByText('120 × 80 mm')).toBeInTheDocument()
    expect(within(single).getByText('2 printers')).toBeInTheDocument()
    expect(within(single).getByText('All that can print it')).toBeInTheDocument()
    expect(within(single).getByText('Prusa Mini+ takes it once its bed is cleared')).toBeInTheDocument()
    expect(single.querySelector('.anticon-check')).toBeInTheDocument()
    expect(within(single).queryByText('Same printer')).not.toBeInTheDocument()

    const batch = row('Waiting', BATCH.id)
    expect(within(batch).getByLabelText('3 copies')).toHaveTextContent('× 3')
    expect(within(batch).getByText('1 left to start')).toBeInTheDocument()
    expect(within(batch).getByText('Same printer')).toBeInTheDocument()
    expect(within(batch).getByText('Has the batch')).toBeInTheDocument()
    expect(within(batch).getByText('T0 PETG · Any colour')).toBeInTheDocument()
    expect(within(batch).getByText('Prusa MK4 prints copy 3 when copy 2 finishes')).toBeInTheDocument()
    expect(batch.querySelector('.anticon-clock-circle')).toBeInTheDocument()

    expect(within(row('Waiting', HELD.id)).getByText('On hold')).toBeInTheDocument()
  })

  it('expands a batch to its copies, the ones left to start in one row', async () => {
    await loadPage(queue())

    // Only the batch expands
    expect(within(row('Waiting', '11')).queryByRole('button', { name: /Show the copies/ })).not.toBeInTheDocument()

    await userEvent.click(within(row('Waiting', BATCH.id)).getByRole('button', { name: 'Show the copies of cable_clip.gcode' }))

    const copies = screen.getByRole('group', { name: 'Copies of cable_clip.gcode' })
    expect(within(copies).getByText('All on Prusa MK4 · 1 done · 1 printing · 1 waiting')).toBeInTheDocument()
    const lines = within(copies).getAllByRole('row').filter((each) => each.dataset.rowKey).map((each) => each.textContent)
    expect(lines[0]).toMatch(/^Copy 1 of 3CompletedPrusa MK4/)
    // The printer's live status
    expect(lines[1]).toMatch(/^Copy 2 of 3PrintingPrusa MK464%, .* left$/)
    expect(lines[2]).toBe('Copy 3 of 3EnqueuedPrusa MK4One after another, after copy 2')
  })

  it('filters the waiting jobs by what happens next, keeping their place in the queue', async () => {
    await loadPage(queue({ waiting: [waitingJob(), blocked([VORON_ZERO]), { ...HELD, id: '14' }] }))

    const filter = (name) => userEvent.click(within(section('Waiting')).getByText(name))
    const shown = () => rows('Waiting').map((each) => within(each).getAllByRole('cell')[0].textContent)

    await filter('Blocked')
    expect(shown()).toEqual(['2'])
    await filter('On Hold')
    expect(shown()).toEqual(['3'])
    await filter('Ready')
    expect(shown()).toEqual(['1'])
    await filter('All')
    expect(shown()).toEqual(['1', '2', '3'])
  })

  it('tints a blocked job and offers Load Filament on the page of the one printer that could print it', async () => {
    await loadPage(queue({ waiting: [blocked([{ __typename: 'Printer', id: '9', name: 'Voron 0.2' }])] }))

    const job = rows('Waiting')[0]
    expect(job.style.background).not.toBe('')
    expect(within(job).getByText(/Blocked: no printer has PLA Black loaded\./)).toBeInTheDocument()
    expect(within(job).getByRole('link', { name: 'Load Filament' })).toHaveAttribute('href', '/printers/9')
  })

  it('lists the printers to load filament on when several could print a blocked job', async () => {
    await loadPage(queue({ waiting: [blocked(waitingJob().eligiblePrinters)] }))

    await userEvent.click(screen.getByRole('button', { name: /Load Filament/ }))
    const menu = await screen.findByRole('menu')
    expect(within(menu).getByRole('link', { name: 'Prusa Mini+' })).toHaveAttribute('href', '/printers/4')
    expect(within(menu).getByRole('link', { name: 'Voron 0.2' })).toHaveAttribute('href', '/printers/9')
  })

  it('offers nothing to load when no printer can print a blocked job', async () => {
    await loadPage(queue({ waiting: [blocked([])] }))

    expect(screen.getByText('Blocked: no printer can print it.')).toBeInTheDocument()
    expect(screen.queryByText(/Load Filament/)).not.toBeInTheDocument()
  })

  it('shows the latest finished prints with how they ended, and All History for later', async () => {
    await loadPage(queue())

    expect(within(row('Finished', '33')).getByText('bracket.gcode')).toBeInTheDocument()
    expect(within(row('Finished', '33')).getByText('Failed')).toBeInTheDocument()
    expect(within(row('Finished', '31')).getByText('cable_clip.gcode · copy 1 of 3')).toBeInTheDocument()
    expect(within(row('Finished', '31')).getByText('Completed')).toBeInTheDocument()
    expect(within(section('Finished')).getByText('All History').closest('.ant-typography-disabled')).toBeInTheDocument()
  })

  it('shows dispatch running, without the paused banner', async () => {
    await loadPage(queue())

    expect(screen.getByRole('switch', { name: 'Dispatch' })).toBeChecked()
    expect(screen.getByText('Dispatching jobs')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Add to Queue/ })).toBeDisabled()
    expect(screen.queryByText('Dispatch is paused')).not.toBeInTheDocument()
    expect(within(section('Waiting')).queryByText('Dispatch paused')).not.toBeInTheDocument()
  })

  it('shows dispatch paused: the switch off, a banner above the lists, Waiting tagged and nothing taken', async () => {
    await loadPage(queue({ dispatchPaused: true }))

    expect(screen.getByRole('switch', { name: 'Dispatch' })).not.toBeChecked()
    expect(screen.getByRole('switch', { name: 'Dispatch' }).parentElement).toHaveTextContent('Dispatch paused')
    const banner = screen.getByRole('alert')
    expect(banner).toHaveTextContent('Dispatch is paused')
    expect(banner).toHaveTextContent('No printer takes a new job until you resume, so 3 prints stay waiting.')
    expect(banner.compareDocumentPosition(section('Available Printers'))).toBe(Node.DOCUMENT_POSITION_FOLLOWING)
    expect(within(section('Waiting')).getByText('Dispatch paused')).toBeInTheDocument()
    expect(within(section('Available Printers')).getByText('2 printers free, not taking jobs while dispatch is paused'))
      .toBeInTheDocument()
    expect(within(row('Available Printers', MINI.id)).getByText('Nothing while dispatch is paused')).toBeInTheDocument()
    expect(row('Available Printers', MINI.id).style.background).toBe('')
  })

  it('shows the empty state with nothing waiting, printing or to clear', async () => {
    renderPage({ ...EMPTY_QUEUE, availablePrinters: [VORON_ZERO] })

    expect(await screen.findByText('The queue is empty')).toBeInTheDocument()
    expect(screen.getByText(/Add a file and say how many copies you need/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Add to Queue/ })).toBeDisabled()
    expect(screen.queryByRole('switch')).not.toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Waiting' })).not.toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Available Printers' })).not.toBeInTheDocument()
  })

  it('says the queue is off when globalQueue is null', async () => {
    renderPage(null)

    expect(await screen.findByText('The print queue is off')).toBeInTheDocument()
  })
})
