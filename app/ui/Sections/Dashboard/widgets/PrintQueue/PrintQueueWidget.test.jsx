import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router'

import PrintQueueWidget from './PrintQueueWidget'
import { ALL_OPTIONS, FIXTURE_NOW, FLEET, HISTORY, QUEUE, historyOf, queueOf } from './fixtures'
import { PRINTERS } from '../Printer/fixtures'

const IDLE = [
  { ...PRINTERS.OPERATIONAL, queuedCount: 0, canStartNext: false, nextJob: null },
  { ...PRINTERS.OFFLINE }
]
const NOTHING = { totalCount: 0, jobs: [] }

const renderWidget = (size, { printer = null, options = {}, printers = FLEET, queue, history, renderStartNext } = {}) => render(
  <MemoryRouter>
    <PrintQueueWidget printers={printers} printerId={printer?.id} size={size} options={{ ...ALL_OPTIONS, ...options }}
      queue={queue !== undefined ? queue : (printer ? queueOf(printer) : QUEUE)}
      history={history !== undefined ? history : (printer ? historyOf(printer) : HISTORY)}
      now={FIXTURE_NOW} renderStartNext={renderStartNext} />
  </MemoryRouter>
)

describe('PrintQueueWidget', () => {
  describe('Small', () => {
    it('shows the number of queued jobs, large', () => {
      renderWidget('S', { queue: null })
      expect(screen.getByText('Print Queue')).toBeInTheDocument()
      expect(screen.getByText('6')).toHaveStyle({ color: '#722ed1' })
      expect(screen.getByText('jobs queued')).toBeInTheDocument()
    })

    it("shows one printer's count, titled with its name, and zero in grey", () => {
      renderWidget('S', { printer: PRINTERS.PRINTING, queue: null })
      expect(screen.getByText('Prusa MK4')).toBeInTheDocument()
      expect(screen.getByText('3')).toBeInTheDocument()
      renderWidget('S', { printers: IDLE, queue: null })
      expect(screen.getByText('0')).toHaveStyle({ color: 'rgba(0, 0, 0, 0.45)' })
    })
  })

  describe('Medium', () => {
    it('shows what prints now, then the next two jobs with their position and printer', () => {
      renderWidget('M')
      expect(screen.getByText('6 queued')).toBeInTheDocument()
      expect(screen.getByText('bracket_v3.gcode')).toBeInTheDocument()
      expect(screen.getByText('spool_holder.gcode').parentElement).toHaveTextContent('1spool_holder.gcodePrusa Mini+')
      expect(screen.getByText('cable_clip_x20.gcode').parentElement).toHaveTextContent('2cable_clip_x20.gcodePrusa MK4')
      expect(screen.queryByText('lid_hinge_v4.gcode')).not.toBeInTheDocument()
    })

    it("shows the current print's time left for one printer", () => {
      renderWidget('M', { printer: PRINTERS.PRINTING })
      expect(screen.getByText('Prusa MK4 queue')).toBeInTheDocument()
      expect(screen.getByText('1 h 12 min left')).toBeInTheDocument()
    })

    it('says the queue is empty, pointing to Files', () => {
      renderWidget('M', { printers: IDLE, queue: NOTHING })
      expect(screen.getByText('Nothing queued')).toBeInTheDocument()
      expect(screen.getByText('Queue is empty')).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'Files' })).toHaveAttribute('href', '/files')
    })
  })

  describe('Large', () => {
    it('shows the printing jobs with their progress, the next jobs, "+ N more" and the ready bar', () => {
      renderWidget('L')
      expect(screen.getByText('Printing')).toBeInTheDocument()
      expect(screen.getByText('Prusa MK4 · 1 h 12 min left')).toBeInTheDocument()
      expect(screen.getByText('Voron 2.4 · Paused at 38%')).toBeInTheDocument()
      expect(screen.getAllByRole('progressbar').map((bar) => bar.getAttribute('aria-valuenow'))).toEqual(['64', '38'])
      expect(screen.getByText('Up next')).toBeInTheDocument()
      expect(screen.getByText('+ 4 more')).toBeInTheDocument()
      expect(screen.getByText('Prusa Mini+ is ready for spool_holder.gcode')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Start Next' })).toBeInTheDocument()
    })

    it('renders Start Next for the ready printer through renderStartNext', () => {
      const renderStartNext = vi.fn((printer) => <button key={printer.id}>Start on {printer.name}</button>)
      renderWidget('L', { printer: PRINTERS.OPERATIONAL, renderStartNext })
      expect(renderStartNext).toHaveBeenCalledWith(PRINTERS.OPERATIONAL)
      expect(screen.getByRole('button', { name: 'Start on Prusa Mini+' })).toBeInTheDocument()
    })

    it('hides the printing jobs and Start Next when their options are off', () => {
      renderWidget('L', { options: { nowPrinting: false, startNext: false } })
      expect(screen.queryByText('Printing')).not.toBeInTheDocument()
      expect(screen.queryByRole('button', { name: 'Start Next' })).not.toBeInTheDocument()
      const rows = screen.getByText('Up next').nextSibling
      expect(within(rows).getAllByText(/\.gcode$/)).toHaveLength(6)
    })

    it('shows the empty-queue illustration, pointing to Files', () => {
      renderWidget('L', { printers: IDLE, queue: NOTHING })
      expect(screen.getByText('Queue is empty')).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'Files' })).toBeInTheDocument()
      expect(screen.queryByText('Up next')).not.toBeInTheDocument()
    })
  })
})
