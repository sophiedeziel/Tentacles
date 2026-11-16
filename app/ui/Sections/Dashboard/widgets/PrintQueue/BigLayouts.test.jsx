import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router'

import PrintQueueWidget from './PrintQueueWidget'
import { ALL_OPTIONS, FIXTURE_NOW, FLEET, HISTORY, QUEUE, historyOf, queueOf } from './fixtures'
import { PRINTERS } from '../Printer/fixtures'

const renderWidget = (size, { printer = null, options = {}, printers = FLEET, queue, history } = {}) => render(
  <MemoryRouter>
    <PrintQueueWidget printers={printers} printerId={printer?.id} size={size} options={{ ...ALL_OPTIONS, ...options }}
      queue={queue !== undefined ? queue : (printer ? queueOf(printer) : QUEUE)}
      history={history !== undefined ? history : (printer ? historyOf(printer) : HISTORY)}
      now={FIXTURE_NOW} />
  </MemoryRouter>
)

const rowTexts = () => within(screen.getByRole('table')).getAllByRole('row').slice(1)
  .map((row) => within(row).getAllByRole('cell').map((cell) => cell.textContent))

// Idle printers named Printer 1 … Printer n, after the fleet
const farm = (count) => FLEET.concat(Array.from({ length: count }, (_, index) => ({
  ...PRINTERS.OPERATIONAL, id: `farm-${index}`, name: `Printer ${index + 1}`, queuedCount: 0, canStartNext: false, nextJob: null
})))

describe('PrintQueueWidget at Extra Large and 4×4', () => {
  it('shows one row per printer, ready printers first, with Start Next on the ready ones', () => {
    renderWidget('XL', { queue: null, history: null })
    expect(screen.getByText('6 queued')).toBeInTheDocument()
    expect(rowTexts()).toEqual([
      ['Prusa Mini+', 'Idle', 'spool_holder.gcode +1', '2', 'Start Next'],
      ['Prusa MK4', 'bracket_v3.gcode1 h 12 min', 'cable_clip_x20.gcode +2', '3', ''],
      ['Voron 2.4', 'enclosure_panel.gcode38%', 'calibration_cube.gcode', '1', ''],
      ['Ender 3 V2', 'Stopped responding', 'Nothing queued', '0', '']
    ])
    expect(screen.queryByText('History')).not.toBeInTheDocument()
    expect(screen.queryByText('Open Print Queues')).not.toBeInTheDocument()
  })

  it('folds the printers past what fits into "+ N more printers"', () => {
    renderWidget('XL', { printers: farm(4), queue: null })
    expect(rowTexts()).toHaveLength(5)
    expect(screen.getByText('+ 3 more printers')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Open Print Queues' })).toHaveAttribute('href', '/printers')
  })

  it('says when every folded printer needs attention', () => {
    const paused = Array.from({ length: 4 }, (_, index) => ({ ...PRINTERS.PAUSED, id: `paused-${index}`, name: `Paused ${index + 1}` }))
    renderWidget('XL', { printers: FLEET.concat(paused), queue: null })
    expect(screen.getByText('+ 3 more printers need attention')).toBeInTheDocument()
  })

  it('shows ten printers at 4×4, with the shared up next list and history underneath', () => {
    renderWidget('XXL', { printers: farm(6) })
    expect(rowTexts()).toHaveLength(10)
    expect(screen.getByText('Up next, all printers')).toBeInTheDocument()
    expect(screen.getByText('gear_v2.gcode').parentElement).toHaveTextContent('gear_v2.gcodeEnder 3 V2 · 40 min agoFailed')
    expect(screen.getByText('benchy.gcode').parentElement).toHaveTextContent('Completed')
  })

  it('lists all printers as one queue with history beside it when one row per printer is off', () => {
    renderWidget('XL', { options: { rowPerPrinter: false } })
    expect(screen.queryByRole('table')).not.toBeInTheDocument()
    expect(screen.getByText('Printing')).toBeInTheDocument()
    expect(screen.getByText('History')).toBeInTheDocument()
    expect(screen.getByText('Prusa Mini+ is ready for spool_holder.gcode')).toBeInTheDocument()
  })

  it("shows one printer's up next on the left and its history on the right", () => {
    renderWidget('XL', { printer: PRINTERS.PRINTING })
    expect(screen.getByText('Prusa MK4 queue')).toBeInTheDocument()
    expect(screen.getByText('1 h 12 min left')).toBeInTheDocument()
    expect(screen.getByText('bracket_v2.gcode').parentElement).toHaveTextContent('bracket_v2.gcode2 h agoCompleted')
  })

  it('keeps the history of a printer with nothing queued, so its failed job stays visible', () => {
    renderWidget('XL', { printer: PRINTERS.ERROR })
    expect(screen.getByText('Nothing queued', { selector: 'span:not([class*="nowrap"])' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Files' })).toBeInTheDocument()
    expect(screen.getByText('Failed')).toBeInTheDocument()
  })

  it('says when a printer has printed nothing yet', () => {
    renderWidget('XXL', { printer: PRINTERS.PRINTING, history: [] })
    expect(screen.getByText('Nothing printed yet.')).toBeInTheDocument()
  })

  it('shows the empty-queue illustration when nothing is printing or queued', () => {
    const idle = [{ ...PRINTERS.OPERATIONAL, queuedCount: 0, canStartNext: false, nextJob: null }]
    const { container } = renderWidget('XXL', { printers: idle, queue: { totalCount: 0, jobs: [] }, history: [] })
    expect(screen.getByText('Queue is empty')).toBeInTheDocument()
    expect(container.querySelector('.ant-empty-image svg')).toBeInTheDocument()
    expect(screen.queryByRole('table')).not.toBeInTheDocument()
  })

  it('shows the history with the shared job status tags', () => {
    renderWidget('XL', { options: { rowPerPrinter: false, history: true } })
    expect(screen.getByText('Failed').closest('.ant-tag')).toHaveClass('ant-tag-error')
  })
})
