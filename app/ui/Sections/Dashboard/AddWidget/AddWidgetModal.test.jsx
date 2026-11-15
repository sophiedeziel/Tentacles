import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import AddWidgetModal from './AddWidgetModal'
import { PRINTERS } from '../widgets/Printer/fixtures'

const renderGallery = () => {
  const dispatch = vi.fn()
  const onClose = vi.fn()
  render(<AddWidgetModal open printers={[PRINTERS.PRINTING, PRINTERS.OPERATIONAL]} dispatch={dispatch} onClose={onClose} />)
  return { dispatch, onClose }
}

describe('AddWidgetModal', () => {
  it('previews the divider and each widget type at its sizes, from fixtures', () => {
    renderGallery()
    const dialog = screen.getByRole('dialog')
    expect(within(dialog).getByRole('button', { name: 'Add Divider, Full width' })).toBeInTheDocument()
    expect(within(dialog).getAllByRole('button', { name: /^Choose Printer/ }).map((button) => button.getAttribute('aria-label')))
      .toEqual(['Choose Printer, Small', 'Choose Printer, Medium', 'Choose Printer, Large', 'Choose Printer, Extra Large'])
    expect(within(dialog).getAllByRole('button', { name: /^Add Print Queue/ })).toHaveLength(5)
    expect(within(dialog).getAllByText('Printer name').length).toBeGreaterThan(0)
    // No camera streams in the gallery, and no button holds another
    expect(dialog.querySelector('img')).toBeNull()
    expect(dialog.querySelector('button button')).toBeNull()
  })

  it('adds a divider', async () => {
    const { dispatch, onClose } = renderGallery()
    await userEvent.click(screen.getByRole('button', { name: 'Add Divider, Full width' }))
    expect(dispatch).toHaveBeenCalledWith({ type: 'addDivider' })
    expect(onClose).toHaveBeenCalled()
  })

  it('adds a Print Queue for all printers, also from the keyboard', async () => {
    const { dispatch } = renderGallery()
    await userEvent.click(screen.getByRole('button', { name: 'Add Print Queue, Extra Extra Large' }))
    expect(dispatch).toHaveBeenCalledWith({ type: 'addWidget', widgetType: 'PRINT_QUEUE', size: 'XXL', printerId: null })
    screen.getByRole('button', { name: 'Add Print Queue, Small' }).focus()
    await userEvent.keyboard('{Enter}')
    expect(dispatch).toHaveBeenLastCalledWith({ type: 'addWidget', widgetType: 'PRINT_QUEUE', size: 'S', printerId: null })
  })

  it('asks which printer a Printer widget shows', async () => {
    const { dispatch } = renderGallery()
    await userEvent.click(screen.getByRole('button', { name: 'Choose Printer, Large' }))
    expect(screen.getByText('Which printer should the Printer (Large) widget show?')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /Back to Widgets/ }))
    await userEvent.click(screen.getByRole('button', { name: 'Choose Printer, Small' }))
    await userEvent.click(screen.getByRole('button', { name: 'Add Printer (Small) widget for Prusa Mini+' }))
    expect(dispatch).toHaveBeenCalledWith({ type: 'addWidget', widgetType: 'PRINTER', size: 'S', printerId: '4' })
  })

  it('closes', async () => {
    const { dispatch, onClose } = renderGallery()
    await userEvent.click(screen.getByRole('button', { name: 'Close' }))
    expect(onClose).toHaveBeenCalled()
    expect(dispatch).not.toHaveBeenCalled()
  })
})
