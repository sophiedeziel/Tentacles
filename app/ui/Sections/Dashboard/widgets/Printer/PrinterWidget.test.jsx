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

  describe('Large', () => {
    it('shows the camera above the job, the state tag, a progress bar and the controls', () => {
      render(
        <PrinterWidget printer={PRINTERS.PRINTING} size="L" options={ALL_OPTIONS} now={FIXTURE_NOW}
          cameraStream={<span>stream</span>} />
      )
      expect(screen.getByText('Live')).toBeInTheDocument()
      expect(screen.getByText('stream')).toBeInTheDocument()
      expect(screen.getByText('Printing').closest('.ant-tag')).toBeInTheDocument()
      expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '64')
      expect(screen.getByRole('button', { name: 'Pause' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument()
      expect(screen.queryByText(/Up next/)).not.toBeInTheDocument()
    })

    it('puts the ring in place of the camera, with temperature tiles and up next', () => {
      renderWidget('PRINTING', 'L', { camera: false })
      expect(screen.queryByText('Live')).not.toBeInTheDocument()
      expect(screen.getByText('Hotend')).toBeInTheDocument()
      expect(screen.getByText('215° / 215°')).toBeInTheDocument()
      expect(screen.getByText('Up next: cable_clip_x20.gcode')).toBeInTheDocument()
    })

    it('shows only the time left when every other option is off', () => {
      renderWidget('PRINTING', 'L', { camera: false, temperatures: false, upNext: false, controls: false })
      expect(screen.queryByText('Hotend')).not.toBeInTheDocument()
      expect(screen.queryByText(/Up next/)).not.toBeInTheDocument()
      expect(screen.queryByRole('button')).not.toBeInTheDocument()
    })

    it('shows the camera placeholder with its reason', () => {
      renderWidget('ERROR', 'L')
      expect(screen.getByText('No camera')).toBeInTheDocument()
      expect(screen.getByText('Add a webcam in OctoPrint')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Reconnect' })).toBeInTheDocument()
    })

    it.each([
      ['PAUSED', ['Resume', 'Cancel']],
      ['OPERATIONAL', ['Start Next']],
      ['CONNECTING', []],
      ['OFFLINE', ['Connect']]
    ])('shows the %s controls', (family, labels) => {
      renderWidget(family, 'L')
      expect(screen.queryAllByRole('button').map((button) => button.textContent)).toEqual(labels)
    })

    it('shows a disabled spinner button while cancelling', () => {
      renderWidget('CANCELLING', 'L')
      expect(screen.getByRole('button', { name: /Cancelling/ })).toBeDisabled()
    })
  })

  describe('Extra Large', () => {
    it('shows every detail beside the camera', () => {
      renderWidget('PAUSED', 'XL')
      expect(screen.getByText('Live')).toBeInTheDocument()
      expect(screen.getByText('Paused at 38%')).toBeInTheDocument()
      expect(screen.getByText('175°')).toBeInTheDocument()
      expect(screen.getByText('100° / 100°')).toBeInTheDocument()
      expect(screen.getByText('Up next: calibration_cube.gcode')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Resume' })).toBeInTheDocument()
    })

    it('shows a large ring instead of the camera when it is off', () => {
      renderWidget('PRINTING', 'XL', { camera: false })
      expect(screen.queryByText('Live')).not.toBeInTheDocument()
      expect(screen.getAllByRole('progressbar')).toHaveLength(1)
    })
  })
})
