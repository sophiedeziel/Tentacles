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
import { BATCH, EMPTY_QUEUE, MINI, MK4, VORON_ZERO, queue, waitingJob } from './fixtures'

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

const section = (name) => screen.getByRole('region', { name })
// The body rows of a section's table (antd adds a hidden measure row)
const rows = (name) => within(section(name)).getAllByRole('row').filter((row) => row.dataset.rowKey)
const row = (name, key) => rows(name).find((each) => each.dataset.rowKey === key)
const blocked = (eligiblePrinters) => waitingJob({
  eligiblePrinters, whatHappensNext: { __typename: 'WhatHappensNext', kind: 'BLOCKED', printer: null, jobsAhead: 0, dispatchPaused: false }
})

describe('QueuePage', () => {
  it('shows the five sections in order', async () => {
    renderPage(queue())

    expect(await screen.findByRole('heading', { name: 'Print Queue' })).toBeInTheDocument()
    expect(screen.getAllByRole('region').map((region) => region.getAttribute('aria-label'))).toEqual([
      'Printers Waiting to Be Cleared', 'Available Printers', 'Printing', 'Waiting', 'Finished'
    ])
  })

  it('shows the printers waiting to be cleared, with the print on their bed', async () => {
    renderPage(queue())
    await screen.findByRole('heading', { name: 'Print Queue' })

    const toClear = row('Printers Waiting to Be Cleared', MINI.id)
    expect(within(toClear).getByRole('link', { name: 'Prusa Mini+' })).toHaveAttribute('href', '/printers/4')
    expect(within(toClear).getByRole('link', { name: 'bracket.gcode' })).toHaveAttribute('href', '/files/22')
    expect(within(toClear).getByText('Waiting for its bed to be cleared')).toBeInTheDocument()
  })

  it('shows the available printers with their loaded filament', async () => {
    renderPage(queue())
    await screen.findByRole('heading', { name: 'Print Queue' })

    const available = row('Available Printers', VORON_ZERO.id)
    expect(within(available).getByRole('link', { name: 'Voron 0.2' })).toBeInTheDocument()
    expect(within(available).getByText('PLA Black loaded')).toBeInTheDocument()
    expect(within(available).getByText('Operational')).toBeInTheDocument()
  })

  it('shows the copies printing, with the progress their printer reports', async () => {
    renderPage(queue())
    await screen.findByRole('heading', { name: 'Print Queue' })

    const printing = row('Printing', '32')
    expect(within(printing).getByRole('link', { name: 'cable_clip.gcode' })).toBeInTheDocument()
    expect(within(printing).getByText('Copy 2 of 3')).toBeInTheDocument()
    expect(within(printing).getByRole('link', { name: 'Prusa MK4' })).toBeInTheDocument()
    // The printer's status says 64%, the print as last saved 40%: the live status wins
    expect(within(printing).getByText('64%')).toBeInTheDocument()
  })

  it('shows the waiting jobs in queue order, with their needs, printers and what happens next', async () => {
    renderPage(queue())
    await screen.findByRole('heading', { name: 'Print Queue' })

    expect(rows('Waiting').map((each) => within(each).getAllByRole('cell')[1].textContent)).toEqual(['1', '2', '3'])

    const single = row('Waiting', '11')
    expect(within(single).getByRole('link', { name: 'phone_stand.gcode' })).toHaveAttribute('href', '/files/20')
    expect(within(single).getByText('PLA Black')).toBeInTheDocument()
    expect(within(single).getByText('120 × 80 mm')).toBeInTheDocument()
    expect(within(single).getByText('Prusa Mini+, Voron 0.2')).toBeInTheDocument()
    expect(within(single).getByText('Goes to the next ready printer')).toBeInTheDocument()
    expect(within(single).queryByText('Same printer')).not.toBeInTheDocument()

    const batch = row('Waiting', BATCH.id)
    expect(within(batch).getByText('× 3')).toBeInTheDocument()
    expect(within(batch).getByText('1 left to start')).toBeInTheDocument()
    expect(within(batch).getByText('Same printer')).toBeInTheDocument()
    expect(within(batch).getByText('Bound to')).toHaveTextContent('Bound to Prusa MK4')
    expect(within(batch).getByText('T0 PETG Any colour')).toBeInTheDocument()
    expect(within(batch).getByText('Prusa MK4 prints the next copy when the current one finishes')).toBeInTheDocument()

    expect(within(row('Waiting', '13')).getByText('On hold')).toBeInTheDocument()
  })

  it('expands a batch to its copies', async () => {
    renderPage(queue())
    await screen.findByRole('heading', { name: 'Print Queue' })

    // Only the batch expands
    expect(within(row('Waiting', '11')).queryByRole('button', { name: /expand row/i })).not.toBeInTheDocument()
    expect(screen.queryByText('1 copy left to start')).not.toBeInTheDocument()

    await userEvent.click(within(row('Waiting', BATCH.id)).getByRole('button', { name: /expand row/i }))

    const copies = within(section('Waiting')).getByText('1 copy left to start').closest('td')
    expect(within(copies).getByText('Copy 1')).toBeInTheDocument()
    expect(within(copies).getByText('Completed')).toBeInTheDocument()
    expect(within(copies).getByText('Copy 2')).toBeInTheDocument()
    expect(within(copies).getByText('Printing · 40%')).toBeInTheDocument()
  })

  it('shows the latest finished prints with how they ended', async () => {
    renderPage(queue())
    await screen.findByRole('heading', { name: 'Print Queue' })

    expect(within(row('Finished', '33')).getByText('Failed')).toBeInTheDocument()
    expect(within(row('Finished', '31')).getByText('Completed')).toBeInTheDocument()
    expect(within(row('Finished', '31')).getByText('Copy 1 of 3')).toBeInTheDocument()
  })

  it('offers Load Filament on the page of the one printer that could print a blocked job', async () => {
    renderPage(queue({ waiting: [blocked([{ __typename: 'Printer', id: '9', name: 'Voron 0.2' }])] }))
    await screen.findByRole('heading', { name: 'Print Queue' })

    expect(screen.getByText('No printer has the needed filament loaded')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Load Filament/ })).toHaveAttribute('href', '/printers/9')
  })

  it('lists the printers to load filament on when several could print a blocked job', async () => {
    renderPage(queue({ waiting: [blocked(waitingJob().eligiblePrinters)] }))
    await screen.findByRole('heading', { name: 'Print Queue' })

    await userEvent.click(screen.getByRole('button', { name: /Load Filament/ }))
    const menu = await screen.findByRole('menu')
    expect(within(menu).getByRole('link', { name: 'Prusa Mini+' })).toHaveAttribute('href', '/printers/4')
    expect(within(menu).getByRole('link', { name: 'Voron 0.2' })).toHaveAttribute('href', '/printers/9')
  })

  it('offers nothing to load when no printer can print a blocked job', async () => {
    renderPage(queue({ waiting: [blocked([])] }))
    await screen.findByRole('heading', { name: 'Print Queue' })

    expect(screen.getByText('No printer can print it')).toBeInTheDocument()
    expect(screen.queryByText(/Load Filament/)).not.toBeInTheDocument()
  })

  it('shows dispatch on, without the paused banner', async () => {
    renderPage(queue())
    await screen.findByRole('heading', { name: 'Print Queue' })

    expect(screen.getByRole('switch', { name: 'Dispatch' })).toBeChecked()
    expect(screen.getByText('Dispatch on')).toBeInTheDocument()
    expect(screen.queryByText('Dispatch is paused')).not.toBeInTheDocument()
    expect(within(section('Waiting')).queryByText('Dispatch paused')).not.toBeInTheDocument()
  })

  it('shows dispatch paused: the switch off, a banner above the lists and Waiting labelled', async () => {
    renderPage(queue({ dispatchPaused: true }))
    await screen.findByRole('heading', { name: 'Print Queue' })

    expect(screen.getByRole('switch', { name: 'Dispatch' })).not.toBeChecked()
    expect(screen.getByRole('switch', { name: 'Dispatch' })).toBeDisabled()
    const banner = screen.getByRole('alert')
    expect(banner).toHaveTextContent('Dispatch is paused')
    expect(banner.compareDocumentPosition(section('Printers Waiting to Be Cleared')))
      .toBe(Node.DOCUMENT_POSITION_FOLLOWING)
    expect(within(section('Waiting')).getByText('Dispatch paused')).toBeInTheDocument()
  })

  it('shows the empty state with nothing waiting, printing or to clear', async () => {
    renderPage({ ...EMPTY_QUEUE, availablePrinters: [VORON_ZERO] })

    expect(await screen.findByText('Nothing in the queue')).toBeInTheDocument()
    expect(screen.getByText('Queued files wait here, then print on the next printer that can take them.'))
      .toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Add to Queue/ })).toBeDisabled()
    expect(screen.queryByRole('region', { name: 'Waiting' })).not.toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Available Printers' })).not.toBeInTheDocument()
  })

  it('says the queue is off when globalQueue is null', async () => {
    renderPage(null)

    expect(await screen.findByText('The print queue is off')).toBeInTheDocument()
  })
})
