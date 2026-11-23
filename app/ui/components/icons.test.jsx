import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import * as icons from './icons'

const LABELS = {
  Printer3DOutlined: '3D printer',
  HotendOutlined: 'Hotend / nozzle',
  HeatedBedOutlined: 'Heated bed',
  FilamentOutlined: 'Filament spool',
  LayersOutlined: 'Layers',
  ExtruderOutlined: 'Extruder',
  PrintQueueOutlined: 'Print queue',
  GcodeFileOutlined: 'G-code file',
  WebcamOutlined: 'Webcam',
  TemperatureOutlined: 'Temperature'
}

describe('icons', () => {
  it('exports the ten Tentacles icons', () => {
    expect(Object.keys(icons).sort()).toEqual(Object.keys(LABELS).sort())
  })

  it.each(Object.entries(LABELS))('%s is an image labelled "%s"', (name, label) => {
    const Icon = icons[name]
    render(<Icon />)

    const img = screen.getByRole('img', { name: label })
    expect(img).toHaveClass('anticon')
    expect(img.querySelectorAll('path').length).toBeGreaterThan(0)
  })

  it('lets a decorative icon hide from screen readers', () => {
    render(<icons.LayersOutlined aria-hidden />)

    expect(screen.queryByRole('img')).not.toBeInTheDocument()
  })

  it('takes another label', () => {
    render(<icons.Printer3DOutlined aria-label="Printing" />)

    expect(screen.getByRole('img', { name: 'Printing' })).toBeInTheDocument()
  })
})
