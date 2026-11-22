import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import EditBar, { EditNotice } from './EditBar'

const names = () => screen.getAllByRole('button').map((button) => button.textContent)

describe('EditBar', () => {
  it('offers Edit Dashboard in view mode', async () => {
    const onEdit = vi.fn()
    render(<EditBar editing={false} onEdit={onEdit} />)
    await userEvent.click(screen.getByRole('button', { name: /Edit Dashboard/ }))
    expect(onEdit).toHaveBeenCalled()
  })

  it('offers the edit actions in edit mode', async () => {
    const actions = { onReset: vi.fn(), onAddDivider: vi.fn(), onAddWidget: vi.fn(), onDone: vi.fn() }
    render(<EditBar editing {...actions} />)
    expect(names()).toEqual(['Reset Layout', 'Add Divider', 'Add Widget', 'Done'])
    await userEvent.click(screen.getByRole('button', { name: 'Reset Layout' }))
    await userEvent.click(screen.getByRole('button', { name: 'Add Divider' }))
    await userEvent.click(screen.getByRole('button', { name: /Add Widget/ }))
    await userEvent.click(screen.getByRole('button', { name: 'Done' }))
    Object.values(actions).forEach((action) => expect(action).toHaveBeenCalledTimes(1))
  })

  it('holds the other actions while saving', () => {
    render(<EditBar editing busy="save" onReset={vi.fn()} onAddDivider={vi.fn()} onDone={vi.fn()} />)
    expect(screen.getByRole('button', { name: 'Reset Layout' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Add Divider' })).toBeDisabled()
  })

  it('names every size in the edit hint, as the widget toolbar does', () => {
    render(<EditNotice />)
    expect(screen.getByText(/Pick S, M, L, XL or XXL to resize\./)).toBeInTheDocument()
    expect(screen.getByText(/On a touch screen, hold a widget before you drag it\./)).toBeInTheDocument()
  })
})
