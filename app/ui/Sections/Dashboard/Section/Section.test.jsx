import React from 'react'
import { describe, expect, it } from 'vitest'
import { render as renderElement, screen } from '@testing-library/react'
import { MockedProvider } from '@apollo/client/testing/react'
import Section from './Section'
import { ALL_OPTIONS, FIXTURE_NOW, PRINTERS } from '../widgets/Printer/fixtures'

// Printer tiles run their controls through Apollo
const render = (element) => renderElement(<MockedProvider mocks={[]}>{element}</MockedProvider>)

const data = { printersById: { 1: PRINTERS.PRINTING }, now: FIXTURE_NOW.getTime() }
const printerWidget = (id, widthUnits, heightUnits) => ({
  id, type: 'PRINTER', widthUnits, heightUnits, printer: { id: '1' }, options: { ...ALL_OPTIONS, camera: false }
})

describe('Section', () => {
  it('shows the divider title and lays its widgets out by span', () => {
    const { container } = render(
      <Section data={data} section={{ id: '2', title: 'Workshop', widgets: [printerWidget('w1', 2, 1), printerWidget('w2', 4, 2)] }} />
    )
    expect(screen.getByText('Workshop')).toBeInTheDocument()
    const cells = container.querySelectorAll('[data-size]')
    expect([...cells].map((cell) => cell.dataset.size)).toEqual(['M', 'XL'])
    expect(cells[1].style.getPropertyValue('--width-units')).toBe('4')
    expect(cells[1].style.getPropertyValue('--width-units-md')).toBe('2')
    expect(cells[1].style.getPropertyValue('--height-units')).toBe('2')
  })

  it('has no divider for the first section', () => {
    render(<Section data={data} section={{ id: '1', title: null, widgets: [printerWidget('w1', 1, 1)] }} />)
    expect(screen.getByRole('region', { name: 'Top of dashboard' })).toBeInTheDocument()
    expect(screen.getByText('Prusa MK4')).toBeInTheDocument()
  })

  it('stands in for a Print Queue until that widget exists', () => {
    render(<Section data={data} section={{
      id: '1', title: null, widgets: [{ id: 'q', type: 'PRINT_QUEUE', widthUnits: 4, heightUnits: 2, printer: null, options: {} }]
    }} />)
    expect(screen.getByText('Print Queue')).toBeInTheDocument()
    expect(screen.getByText('· Coming soon')).toBeInTheDocument()
  })
})
