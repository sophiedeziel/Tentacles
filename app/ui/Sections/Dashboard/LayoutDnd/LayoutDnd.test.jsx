import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { act, fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'

import EditableSections from '../DashboardPage/EditableSections'
import { draftFrom } from '../layout/layoutReducer'
import { ALL_OPTIONS, FIXTURE_NOW, PRINTERS } from '../widgets/Printer/fixtures'

const data = { printers: [PRINTERS.PRINTING], printersById: { 1: PRINTERS.PRINTING }, now: FIXTURE_NOW.getTime() }
const sections = draftFrom({
  sections: [{
    id: '1',
    title: null,
    widgets: [{
      id: 'w1', type: 'PRINTER', widthUnits: 2, heightUnits: 1, printer: { id: '1' }, options: { ...ALL_OPTIONS, camera: false }
    }]
  }]
})

const renderSections = () => render(
  <MockedProvider mocks={[]}>
    <EditableSections editor={{ sections, dispatch: vi.fn() }} data={data} />
  </MockedProvider>
)

// The widget's own cell, which is what picks it up. Touch events go to where the touch started.
const cell = () => screen.getByRole('button', { name: 'Prusa MK4' })
const at = (x, y) => ({ touches: [{ clientX: x, clientY: y }] })
const wait = (ms) => act(() => new Promise((resolve) => setTimeout(resolve, ms)))

describe('LayoutDnd on touch screens', () => {
  it('picks a widget up when a finger rests on it', async () => {
    renderSections()
    fireEvent.touchStart(cell(), at(50, 50))
    await wait(100)
    expect(cell()).not.toHaveAttribute('aria-pressed')
    await wait(250)
    expect(cell()).toHaveAttribute('aria-pressed', 'true')
    fireEvent.touchEnd(cell())
  })

  it('leaves a swipe to scroll the page', async () => {
    renderSections()
    fireEvent.touchStart(cell(), at(50, 50))
    fireEvent.touchMove(cell(), at(50, 20))
    await wait(350)
    expect(cell()).not.toHaveAttribute('aria-pressed')
  })

  it('never picks a widget up from its settings menu', async () => {
    renderSections()
    await userEvent.click(screen.getByRole('button', { name: 'Settings for Prusa MK4' }))
    const menu = await screen.findByText('Printer settings')
    fireEvent.touchStart(menu, at(50, 50))
    await wait(350)
    expect(cell()).not.toHaveAttribute('aria-pressed')
    fireEvent.touchEnd(menu)
    fireEvent.mouseDown(menu, { clientX: 50, clientY: 50 })
    fireEvent.mouseMove(document, { clientX: 90, clientY: 90 })
    expect(cell()).not.toHaveAttribute('aria-pressed')
    fireEvent.mouseUp(document)
  })
})
