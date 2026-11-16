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

  it.each(Object.keys(LABELS))('%s draws 1em lines in the text colour on a 24 px grid', (name) => {
    const Icon = icons[name]
    const { container } = render(<Icon />)

    const svg = container.querySelector('svg')
    expect(svg).toHaveAttribute('viewBox', '0 0 24 24')
    expect(svg).toHaveAttribute('width', '1em')
    expect(svg).toHaveAttribute('height', '1em')
    expect(svg).toHaveAttribute('fill', 'none')
    expect(svg).toHaveAttribute('stroke', 'currentColor')
    expect(svg).toHaveAttribute('stroke-width', '1.5')
    expect(svg).toHaveAttribute('stroke-linecap', 'round')
    expect(svg).toHaveAttribute('stroke-linejoin', 'round')
    expect(svg).toHaveAttribute('focusable', 'false')
    expect(svg).toHaveAttribute('aria-hidden', 'true')
  })

  it('passes its props to the icon', () => {
    const { container } = render(<icons.HotendOutlined className="hot" style={{ color: 'red' }} title="Nozzle" />)

    const span = container.firstChild
    expect(span).toHaveClass('anticon', 'hot')
    expect(span).toHaveStyle({ color: 'rgb(255, 0, 0)' })
    expect(span).toHaveAttribute('title', 'Nozzle')
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
