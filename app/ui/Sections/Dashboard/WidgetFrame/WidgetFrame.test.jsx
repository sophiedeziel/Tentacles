import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import WidgetFrame from './WidgetFrame'

const edit = (overrides = {}) => ({
  title: 'Prusa MK4',
  sizes: ['S', 'M', 'L', 'XL'],
  size: 'L',
  onResize: vi.fn(),
  canMoveEarlier: false,
  canMoveLater: true,
  onMove: vi.fn(),
  onRemove: vi.fn(),
  ...overrides
})

describe('WidgetFrame', () => {
  it('shows only the widget in view mode', () => {
    render(<WidgetFrame label="Printer"><button>Pause</button></WidgetFrame>)
    expect(screen.getByRole('button', { name: 'Pause' })).toBeInTheDocument()
    expect(screen.queryByRole('group', { name: 'Widget size' })).not.toBeInTheDocument()
  })

  it('makes the widget inert in edit mode', () => {
    render(<WidgetFrame label="Printer" edit={edit()}><button>Pause</button></WidgetFrame>)
    expect(screen.getByText('Pause').closest('[inert]')).not.toBeNull()
  })

  it('offers the sizes of its type, with the current one pressed', async () => {
    const tools = edit()
    render(<WidgetFrame label="Printer" edit={tools}>widget</WidgetFrame>)
    const sizes = screen.getByRole('group', { name: 'Widget size' })
    expect([...sizes.querySelectorAll('button')].map((button) => button.textContent)).toEqual(['S', 'M', 'L', 'XL'])
    expect(screen.getByRole('button', { name: 'Large' })).toHaveAttribute('aria-pressed', 'true')
    await userEvent.click(screen.getByRole('button', { name: 'Extra Large' }))
    expect(tools.onResize).toHaveBeenCalledWith('XL')
  })

  it('moves and removes the widget', async () => {
    const tools = edit()
    render(<WidgetFrame label="Printer" edit={tools}>widget</WidgetFrame>)
    expect(screen.getByRole('button', { name: 'Move earlier' })).toBeDisabled()
    await userEvent.click(screen.getByRole('button', { name: 'Move later' }))
    expect(tools.onMove).toHaveBeenCalledWith(1)
    await userEvent.click(screen.getByRole('button', { name: 'Remove Prusa MK4' }))
    expect(tools.onRemove).toHaveBeenCalled()
  })
})
