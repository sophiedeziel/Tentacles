import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import PrinterWidget from './PrinterWidget'
import { ALL_OPTIONS, FIXTURE_NOW, PRINTERS } from './fixtures'

const renderWidget = (family, size, options = {}) => render(
  <PrinterWidget printer={PRINTERS[family]} size={size} options={{ ...ALL_OPTIONS, ...options }} now={FIXTURE_NOW} />
)

describe('PrinterWidget', () => {
  describe('Small', () => {
    it('shows the name, the progress ring, the time left and the state', () => {
      renderWidget('PRINTING', 'S')
      expect(screen.getByText('Prusa MK4')).toBeInTheDocument()
      expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '64')
      expect(screen.getByText('1 h 12 min left')).toBeInTheDocument()
      expect(screen.getByText('Printing')).toBeInTheDocument()
    })

    it('shows the state icon instead of a ring when no job is under way', () => {
      renderWidget('ERROR', 'S')
      expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
      expect(screen.getByTitle('Offline after error')).toBeInTheDocument()
    })
  })

  describe('Medium', () => {
    it('shows the ring, the job, the time and the temperatures', () => {
      renderWidget('PRINTING', 'M', { camera: false })
      expect(screen.getByRole('progressbar')).toBeInTheDocument()
      expect(screen.getByText('bracket_v3.gcode')).toBeInTheDocument()
      expect(screen.getByText(/^1 h 12 min left · done at/)).toBeInTheDocument()
      expect(screen.getByText('Hotend 215° / 215° · Bed 60° / 60°')).toBeInTheDocument()
    })

    it('hides the temperatures when the option is off', () => {
      renderWidget('PRINTING', 'M', { camera: false, temperatures: false })
      expect(screen.queryByText(/Hotend/)).not.toBeInTheDocument()
    })

    it('fills the tile with the camera and puts the details on a strip', () => {
      render(
        <PrinterWidget printer={PRINTERS.PRINTING} size="M" options={ALL_OPTIONS} now={FIXTURE_NOW}
          cameraStream={<span>stream</span>} />
      )
      expect(screen.getByText('stream')).toBeInTheDocument()
      expect(screen.getByText('64%')).toBeInTheDocument()
      expect(screen.getByText(/^1 h 12 min left · done at .* · Hotend 215° \/ 215° · Bed 60° \/ 60°$/)).toBeInTheDocument()
    })

    it('says the camera is offline when the printer cannot be reached', () => {
      renderWidget('OFFLINE', 'M')
      expect(screen.getByText('Camera offline')).toBeInTheDocument()
      expect(screen.getByText('Last seen 2 h ago')).toBeInTheDocument()
    })
  })
})
