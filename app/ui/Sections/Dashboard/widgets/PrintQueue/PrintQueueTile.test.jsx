import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { App } from 'antd'
import { MemoryRouter } from 'react-router'

import PrintQueueTile from './PrintQueueTile'
import { PRINT_QUEUE_WIDGET } from '../../graphql/printQueue'
import { ACTIONS } from '../../graphql/actions'
import { ALL_OPTIONS, FIXTURE_NOW, FLEET, HISTORY, QUEUE } from './fixtures'
import { PRINTERS } from '../Printer/fixtures'

const typedJob = (job) => ({
  __typename: 'EnqueuedJob',
  ...job,
  executable: { __typename: 'File', ...job.executable },
  printer: { __typename: 'Printer', ...job.printer }
})
const queueResult = (queue) => ({ __typename: 'PrintQueue', totalCount: queue.totalCount, jobs: queue.jobs.map(typedJob) })

const listsMock = (variables, data) => {
  const result = vi.fn(() => ({ data }))
  return { mock: { request: { query: PRINT_QUEUE_WIDGET, variables }, result, maxUsageCount: 10 }, result }
}

const variables = (printerId, queueRows, historyRows) => ({
  printerId, queueRows, historyRows, withQueue: queueRows > 0, withHistory: historyRows > 0
})

const tile = (size, { printerId = null, options = {}, queueVersion = 0, live = true, editing = false } = {}) => (
  <PrintQueueTile size={size}
    widget={{ printer: printerId ? { id: printerId } : null, options: { ...ALL_OPTIONS, ...options } }}
    data={{ printers: FLEET, now: FIXTURE_NOW.getTime(), live, queueVersion, editing }} />
)

const renderTile = (element, mocks = []) => render(
  <MockedProvider mocks={mocks}><App><MemoryRouter>{element}</MemoryRouter></App></MockedProvider>
)

describe('PrintQueueTile', () => {
  it('loads nothing at Small: the printers have the counts', () => {
    const { mock, result } = listsMock(variables(null, 0, 0), {})
    renderTile(tile('S'), [mock])
    expect(screen.getByText('6')).toBeInTheDocument()
    expect(result).not.toHaveBeenCalled()
  })

  it('loads the up next rows Large fits, and no history', async () => {
    const { mock } = listsMock(variables(null, 8, 0), { printQueue: queueResult(QUEUE) })
    renderTile(tile('L'), [mock])
    expect(await screen.findByText('cable_clip_x20.gcode')).toBeInTheDocument()
    expect(screen.getByText('+ 4 more')).toBeInTheDocument()
  })

  it("loads one printer's queue and history at Extra Large", async () => {
    const mk4 = QUEUE.jobs.filter((job) => job.printer.id === '1')
    const { mock } = listsMock(variables('1', 8, 7), {
      printQueue: queueResult({ totalCount: 3, jobs: mk4 }),
      jobHistory: HISTORY.filter((job) => job.printer.id === '1').map(typedJob)
    })
    renderTile(tile('XL', { printerId: '1' }), [mock])
    expect(await screen.findByText('benchy.gcode')).toBeInTheDocument()
    expect(screen.getByText('Prusa MK4 queue')).toBeInTheDocument()
  })

  it('reloads its lists when the queue changes', async () => {
    const { mock, result } = listsMock(variables(null, 3, 0), { printQueue: queueResult(QUEUE) })
    const { rerender } = renderTile(tile('M'), [mock])
    await screen.findByText('spool_holder.gcode')
    expect(result).toHaveBeenCalledTimes(1)
    rerender(<MockedProvider mocks={[mock]}><App><MemoryRouter>{tile('M', { queueVersion: 1 })}</MemoryRouter></App></MockedProvider>)
    await waitFor(() => expect(result).toHaveBeenCalledTimes(2))
  })

  it('does not reload on mount when the queue changed before it was added', async () => {
    const { mock, result } = listsMock(variables(null, 3, 0), { printQueue: queueResult(QUEUE) })
    renderTile(tile('M', { queueVersion: 4 }), [mock])
    await screen.findByText('spool_holder.gcode')
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(result).toHaveBeenCalledTimes(1)
  })

  it('starts the next print on the ready printer after asking, naming the job it confirmed', async () => {
    const started = vi.fn(() => ({ data: { startNextPrint: { __typename: 'StartNextPrintPayload', success: true, errors: [] } } }))
    const { mock } = listsMock(variables(null, 0, 0), {})
    renderTile(tile('XL', { live: false }), [mock, {
      request: { query: ACTIONS.startNext.document, variables: { printerId: '4', expectedJobId: PRINTERS.OPERATIONAL.nextJob.id } },
      result: started
    }])
    await userEvent.click(screen.getByRole('button', { name: 'Start Next' }))
    expect(await screen.findByText(
      'spool_holder.gcode starts on Prusa Mini+. Make sure the bed is clear. Printer states may be out of date.'
    )).toBeInTheDocument()
    expect(started).not.toHaveBeenCalled()
    await userEvent.click(screen.getByRole('button', { name: 'Start Print' }))
    await waitFor(() => expect(started).toHaveBeenCalledTimes(1))
  })

  // The edit toolbar sits over the bottom of the widget, where the ready bar is
  it('hides the ready bar and its Start Next in edit mode', async () => {
    const { mock } = listsMock(variables(null, 8, 0), { printQueue: queueResult(QUEUE) })
    renderTile(tile('L', { editing: true }), [mock])
    expect(await screen.findByText('cable_clip_x20.gcode')).toBeInTheDocument()
    expect(screen.queryByText('Prusa Mini+ is ready for spool_holder.gcode')).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Start Next' })).not.toBeInTheDocument()
  })

  it('hides Start Next in the table in edit mode', () => {
    const { mock } = listsMock(variables(null, 0, 0), {})
    renderTile(tile('XL', { editing: true }), [mock])
    expect(screen.getByRole('table', { name: 'Queues by printer' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Start Next' })).not.toBeInTheDocument()
  })
})
