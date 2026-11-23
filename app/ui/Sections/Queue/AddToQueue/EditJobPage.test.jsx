import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { MemoryRouter, Route, Routes } from 'react-router'

import EditJobPage from './EditJobPage'
import { EDIT_PRINT_JOB, PRINTER_FITS, QUEUE_ESTIMATE, UPDATE_PRINT_JOB } from './graphql/addToQueue'
import { HOLD_PRINT_JOB, RELEASE_PRINT_JOB } from '../graphql/actions'
import { estimateFor, file, fitsFor } from './fixtures'

const always = { maxUsageCount: Number.POSITIVE_INFINITY }

// bracket_v3.gcode × 3 asked in PETG, Any colour (its G-code says PLA Black), on the Ender only: 1 done, 1 printing,
// 1 waiting, second of the waiting jobs
const JOB = {
  __typename: 'PrintJob',
  id: '12',
  copies: 3,
  material: 'PETG',
  colour: null,
  samePrinter: false,
  allCapable: false,
  held: false,
  waitingPosition: 2,
  copiesLeftToStart: 1,
  printers: [{ __typename: 'Printer', id: '2' }],
  prints: [
    { __typename: 'Print', id: '31', status: 'COMPLETED' },
    { __typename: 'Print', id: '32', status: 'ACTIVE' }
  ],
  file: file()
}

const payload = (field, { errors = [] } = {}) => ({
  data: {
    [field]: {
      __typename: 'Payload',
      success: errors.length === 0,
      errors: errors.map((message) => ({ __typename: 'UserError', field: null, message })),
      printJob: null
    }
  }
})

// A server answering the job, every fits and estimate request, updatePrintJob with `refusal` (none: saved), and
// holdPrintJob / releasePrintJob. `calls` records what was sent.
const server = ({ job = JOB, refusal = null } = {}) => {
  const calls = { estimates: [], updates: [], holds: [], releases: [] }
  const mocks = [
    {
      request: { query: EDIT_PRINT_JOB, variables: { id: '12' } },
      result: {
        data: {
          globalQueue: { __typename: 'GlobalQueue', printJob: job },
          filamentMaterials: ['PLA', 'PETG', 'ABS'],
          filamentColours: ['Black', 'White', 'Grey', 'Red']
        }
      },
      ...always
    },
    {
      request: { query: PRINTER_FITS, variables: () => true },
      result: (variables) => ({ data: { printerFits: fitsFor(variables) } }),
      ...always
    },
    {
      request: { query: QUEUE_ESTIMATE, variables: () => true },
      result: (variables) => {
        calls.estimates.push(variables)
        return { data: { queueEstimate: estimateFor(variables) } }
      },
      ...always
    },
    {
      request: { query: UPDATE_PRINT_JOB, variables: () => true },
      result: (variables) => {
        calls.updates.push(variables)
        return payload('updatePrintJob', { errors: refusal ? [refusal] : [] })
      },
      ...always
    },
    {
      request: { query: HOLD_PRINT_JOB, variables: () => true },
      result: (variables) => {
        calls.holds.push(variables)
        return payload('holdPrintJob')
      },
      ...always
    },
    {
      request: { query: RELEASE_PRINT_JOB, variables: () => true },
      result: (variables) => {
        calls.releases.push(variables)
        return payload('releasePrintJob')
      },
      ...always
    }
  ]
  return { calls, mocks }
}

const renderPage = (options) => {
  const { calls, mocks } = server(options)
  render(
    <MockedProvider cache={new InMemoryCache()} mocks={mocks}>
      <MemoryRouter initialEntries={['/queue/12/edit']}>
        <Routes>
          <Route path="/queue" element={<div>The queue page</div>} />
          <Route path="/queue/:printJobId/edit" element={<EditJobPage />} />
        </Routes>
      </MemoryRouter>
    </MockedProvider>
  )
  return calls
}

const section = (name) => screen.getByRole('region', { name })
const loaded = () => screen.findByRole('heading', { name: 'Edit bracket_v3.gcode in the Queue' })
const printerBox = (name) => within(section('Printers')).getByRole('checkbox', { name })
// The form, once the fits and the estimate answered
const ready = async () => {
  await loaded()
  await within(section('Summary')).findByText('2 printing · 5 jobs waiting')
  await waitFor(() => expect(printerBox('Prusa MK4')).toBeInTheDocument())
}

describe('the Edit page', () => {
  it('starts from the job as saved, not from its G-code', async () => {
    renderPage()
    await ready()

    expect(screen.getByText('Changes apply to the copies still waiting. The job keeps its place in the queue.'))
      .toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Print Queue/ })).toHaveAttribute('href', '/queue')
    const filament = section('Filament')
    expect(within(filament).getByText('PETG')).toBeInTheDocument()
    expect(within(filament).getByText('Any Colour')).toBeInTheDocument()
    expect(within(filament).getByText('Any colour is accepted. The G-code says Black')).toBeInTheDocument()
    expect(screen.getByRole('spinbutton', { name: 'Copies' })).toHaveValue('3')
  })

  it('ticks the printers the job is limited to', async () => {
    renderPage()
    await ready()

    expect(printerBox('Ender 3 V2')).toBeChecked()
    expect(printerBox('Prusa MK4')).not.toBeChecked()
    expect(printerBox('Voron 2.4')).not.toBeChecked()
    expect(within(section('Printers')).getByText('1 of 3 selected')).toBeInTheDocument()
  })

  it('selects every printer that can print it for a job every printer may take', async () => {
    renderPage({ job: { ...JOB, allCapable: true, printers: [] } })
    await ready()

    expect(printerBox('Prusa MK4')).toBeChecked()
    expect(printerBox('Ender 3 V2')).toBeChecked()
    expect(printerBox('Mini Delta')).toBeDisabled()
  })

  it('shows its place read-only, and never goes below the copies done and printing', async () => {
    const calls = renderPage()
    await ready()

    const order = section('Order and Timing')
    expect(within(order).getByText('2 of 5 in Waiting')).toBeInTheDocument()
    expect(within(order).getByText('Editing does not move the job. Use Move to Top or Move to Bottom in the queue.'))
      .toBeInTheDocument()
    expect(within(order).queryByText('Next Up')).not.toBeInTheDocument()
    expect(screen.getByRole('spinbutton', { name: 'Copies' })).toHaveAttribute('aria-valuemin', '2')
    // The estimate counts the job's copies still waiting
    expect(calls.estimates.at(-1)).toMatchObject({ printJobId: '12', copies: 3 })
  })

  it('saves the options with updatePrintJob, then goes back to the queue', async () => {
    const calls = renderPage()
    await ready()

    await userEvent.click(printerBox('Prusa MK4'))
    await userEvent.click(screen.getByRole('button', { name: 'Save Changes' }))

    expect(await screen.findByText('The queue page')).toBeInTheDocument()
    expect(calls.updates).toEqual([{
      id: '12', copies: 3, material: 'PETG', colour: null, samePrinter: false, printerIds: ['1', '2']
    }])
    expect(calls.holds).toEqual([])
    expect(calls.releases).toEqual([])
  })

  it('holds the job after saving when the hold was switched on', async () => {
    const calls = renderPage()
    await ready()

    await userEvent.click(screen.getByRole('switch', { name: 'Hold until I release it' }))
    await userEvent.click(screen.getByRole('button', { name: 'Save Changes' }))

    expect(await screen.findByText('The queue page')).toBeInTheDocument()
    expect(calls.updates).toHaveLength(1)
    expect(calls.holds).toEqual([{ id: '12' }])
  })

  it('releases a held job when the hold was switched off', async () => {
    const calls = renderPage({ job: { ...JOB, held: true } })
    await ready()

    await userEvent.click(screen.getByRole('switch', { name: 'Hold until I release it' }))
    await userEvent.click(screen.getByRole('button', { name: 'Save Changes' }))

    expect(await screen.findByText('The queue page')).toBeInTheDocument()
    expect(calls.releases).toEqual([{ id: '12' }])
  })

  it('stays on the form with the reason when the server refuses, and leaves the hold alone', async () => {
    const calls = renderPage({ refusal: "Can't go below 2: 1 done and 1 printing" })
    await ready()

    await userEvent.click(screen.getByRole('switch', { name: 'Hold until I release it' }))
    await userEvent.click(screen.getByRole('button', { name: 'Save Changes' }))

    expect(await screen.findByText("Can't go below 2: 1 done and 1 printing")).toBeInTheDocument()
    expect(screen.queryByText('The queue page')).not.toBeInTheDocument()
    expect(calls.holds).toEqual([])
  })

  it('discards the changes', async () => {
    const calls = renderPage()
    await ready()

    await userEvent.click(printerBox('Prusa MK4'))
    await userEvent.click(screen.getByRole('button', { name: 'Discard Changes' }))

    expect(await screen.findByText('The queue page')).toBeInTheDocument()
    expect(calls.updates).toEqual([])
  })

  it('says so when nothing of the job is waiting any more', async () => {
    renderPage({ job: { ...JOB, copiesLeftToStart: 0 } })

    expect(await screen.findByText('Nothing of this job is waiting any more')).toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Summary' })).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Back to the Print Queue' })).toHaveAttribute('href', '/queue')
  })

  it('says so when the job is no longer in the queue', async () => {
    renderPage({ job: null })

    expect(await screen.findByText('This job is no longer in the queue')).toBeInTheDocument()
  })
})
