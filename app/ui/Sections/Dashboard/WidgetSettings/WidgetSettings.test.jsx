import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import WidgetSettings from './WidgetSettings'
import { REGISTRY } from '../widgets/registry'
import { PRINTERS } from '../widgets/Printer/fixtures'

const PRINTER_LIST = [PRINTERS.PRINTING, PRINTERS.OPERATIONAL]

const renderSettings = (type, size, widget) => {
  const dispatch = vi.fn()
  const entry = REGISTRY[type]
  render(
    <WidgetSettings entry={entry} size={size} sizeLabel={`${size} label`} printers={PRINTER_LIST} dispatch={dispatch}
      widget={{ key: 'w1', printer: null, options: entry.defaultOptions(size), ...widget }} />
  )
  return dispatch
}

const toggles = () => screen.queryAllByRole('checkbox').map((checkbox) => checkbox.closest('label').textContent)

describe('WidgetSettings', () => {
  it('shows a small Printer only Time left, and says what larger sizes add', () => {
    renderSettings('PRINTER', 'S', { printer: { id: '1' } })
    expect(screen.getByText('Printer settings')).toBeInTheDocument()
    expect(screen.getByText('S label')).toBeInTheDocument()
    expect(toggles()).toEqual(['Time left'])
    expect(screen.getByText('Larger sizes add: Camera, Temperatures, Up next, Controls')).toBeInTheDocument()
  })

  it('gives the options their hints at the sizes that have them', () => {
    renderSettings('PRINTER', 'M', { printer: { id: '1' } })
    expect(toggles()).toEqual(['Camera', 'Time left', 'Temperatures'])
    expect(screen.getByText('The stream fills the tile')).toBeInTheDocument()
    expect(screen.getByText('Larger sizes add: Up next, Controls')).toBeInTheDocument()
  })

  it('shows every option at Large, with nothing more to add', () => {
    renderSettings('PRINTER', 'L', { printer: { id: '1' } })
    expect(toggles()).toEqual(['Camera', 'Time left', 'Temperatures', 'Up next', 'Controls'])
    expect(screen.getByText('Pause, Resume, Cancel; each asks first')).toBeInTheDocument()
    expect(screen.queryByText(/Larger sizes add/)).not.toBeInTheDocument()
  })

  it('toggles an option in the draft', async () => {
    const dispatch = renderSettings('PRINTER', 'L', { printer: { id: '1' } })
    await userEvent.click(screen.getByRole('checkbox', { name: 'Camera' }))
    expect(dispatch).toHaveBeenCalledWith({ type: 'setOption', key: 'w1', option: 'camera', value: false })
  })

  it('picks a queue: all printers or one', async () => {
    const dispatch = renderSettings('PRINT_QUEUE', 'L')
    expect(screen.getByText('Print queue settings')).toBeInTheDocument()
    expect(screen.getByText('All printers')).toBeInTheDocument()
    expect(screen.getByText('Larger sizes add: One row per printer, History')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('combobox', { name: 'Queue' }))
    await userEvent.click(await screen.findByTitle('Prusa Mini+'))
    expect(dispatch).toHaveBeenCalledWith({ type: 'setPrinter', key: 'w1', printerId: '4' })
  })

  it('has no row per printer for one printer\'s queue', () => {
    renderSettings('PRINT_QUEUE', 'XL', { printer: { id: '1' } })
    expect(toggles()).toEqual(['Now printing', 'Start Next', 'History'])
  })

  it('offers nothing to show for a small queue', () => {
    renderSettings('PRINT_QUEUE', 'S')
    expect(toggles()).toEqual([])
    expect(screen.queryByText('Show')).not.toBeInTheDocument()
    expect(screen.getByText('Larger sizes add: Now printing, Start Next, One row per printer, History')).toBeInTheDocument()
  })
})
