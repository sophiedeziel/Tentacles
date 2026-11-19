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
  }, { id: '2', title: 'Workshop', widgets: [] }]
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

describe('dragging a divider', () => {
  // The ⋮⋮ handle, which says whether its section is picked up
  const handle = () => screen.getByRole('button', { name: 'Drag Workshop' })
  const bar = () => handle().parentElement
  const press = (target) => {
    fireEvent.mouseDown(target, { clientX: 50, clientY: 50 })
    fireEvent.mouseMove(document, { clientX: 50, clientY: 90 })
  }

  it('picks the section up from anywhere on the bar', () => {
    renderSections()
    press(bar())
    expect(handle()).toHaveAttribute('aria-pressed', 'true')
    fireEvent.mouseUp(document)
  })

  it('picks the section up when a finger rests on the bar', async () => {
    renderSections()
    fireEvent.touchStart(bar(), at(50, 50))
    await wait(350)
    expect(handle()).toHaveAttribute('aria-pressed', 'true')
    fireEvent.touchEnd(bar())
  })

  it('leaves the title and the buttons to work as usual', async () => {
    renderSections()
    const title = screen.getByRole('textbox', { name: 'Section name' })
    for (const target of [title, screen.getByRole('button', { name: 'Move divider earlier' }),
      screen.getByRole('button', { name: 'Remove Divider' })]) {
      press(target)
      expect(handle()).not.toHaveAttribute('aria-pressed')
      fireEvent.mouseUp(document)
    }
    fireEvent.touchStart(title, at(50, 50))
    await wait(350)
    expect(handle()).not.toHaveAttribute('aria-pressed')
    fireEvent.touchEnd(title)
  })

  it('picks the section up with the keyboard from the handle only', async () => {
    renderSections()
    screen.getByRole('textbox', { name: 'Section name' }).focus()
    await userEvent.keyboard(' ')
    expect(handle()).not.toHaveAttribute('aria-pressed')
    handle().focus()
    await userEvent.keyboard(' ')
    expect(handle()).toHaveAttribute('aria-pressed', 'true')
    await userEvent.keyboard('{Escape}')
  })
})
