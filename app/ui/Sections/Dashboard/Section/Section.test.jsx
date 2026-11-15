import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render as renderElement, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import Section from './Section'
import { draftFrom } from '../layout/layoutReducer'
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

  it('renders a Print Queue widget from the printers', () => {
    render(<Section data={{ ...data, printers: [PRINTERS.PRINTING] }} section={{
      id: '1', title: null, widgets: [{ id: 'q', type: 'PRINT_QUEUE', widthUnits: 1, heightUnits: 1, printer: null, options: {} }]
    }} />)
    expect(screen.getByText('Print Queue')).toBeInTheDocument()
    expect(screen.getByText('3')).toBeInTheDocument()
    expect(screen.queryByText('· Coming soon')).not.toBeInTheDocument()
  })

  describe('in edit mode', () => {
    const draft = draftFrom({
      sections: [
        { id: '1', title: null, widgets: [printerWidget('w1', 2, 1), printerWidget('w2', 2, 1)] },
        { id: '2', title: 'Workshop', widgets: [] },
        { id: '3', title: 'Garage', widgets: [] }
      ]
    })
    const renderEdit = (index) => {
      const dispatch = vi.fn()
      render(<Section data={data} section={draft[index]} index={index} editor={{ sections: draft, dispatch }} />)
      return dispatch
    }

    it('edits a divider: its title, ▲ ▼ and Remove Divider', async () => {
      const dispatch = renderEdit(1)
      expect(screen.getByRole('button', { name: 'Move divider earlier' })).toBeDisabled()
      await userEvent.type(screen.getByRole('textbox', { name: 'Section name' }), 's')
      expect(dispatch).toHaveBeenCalledWith({ type: 'renameDivider', key: 'section-2', title: 'Workshops' })
      await userEvent.click(screen.getByRole('button', { name: 'Move divider later' }))
      expect(dispatch).toHaveBeenCalledWith({ type: 'stepDivider', key: 'section-2', step: 1 })
      await userEvent.click(screen.getByRole('button', { name: 'Remove Divider' }))
      expect(dispatch).toHaveBeenCalledWith({ type: 'removeDivider', key: 'section-2' })
    })

    it('can only move the last divider earlier', () => {
      renderEdit(2)
      expect(screen.getByRole('button', { name: 'Move divider earlier' })).toBeEnabled()
      expect(screen.getByRole('button', { name: 'Move divider later' })).toBeDisabled()
    })

    it('shows where widgets go in an empty section', () => {
      renderEdit(1)
      expect(screen.getByText('Drag widgets here')).toBeInTheDocument()
    })

    it('wires the widget tools to the draft', async () => {
      const dispatch = renderEdit(0)
      const [first] = screen.getAllByRole('button', { name: 'Remove Prusa MK4' })
      await userEvent.click(first)
      expect(dispatch).toHaveBeenCalledWith({ type: 'removeWidget', key: 'widget-w1' })
      const [, second] = screen.getAllByRole('button', { name: 'Small' })
      await userEvent.click(second)
      expect(dispatch).toHaveBeenCalledWith({ type: 'resizeWidget', key: 'widget-w2', size: 'S' })
      const later = screen.getAllByRole('button', { name: 'Move later' })
      expect(later.map((button) => button.disabled)).toEqual([false, false])
      await userEvent.click(later[1])
      expect(dispatch).toHaveBeenCalledWith({ type: 'stepWidget', key: 'widget-w2', step: 1 })
    })
  })
})
