import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import AppSwitcher from './AppSwitcher'

describe('AppSwitcher', () => {
  it('serves the redesigned dashboard at /dashboard-next', async () => {
    render(
      <MemoryRouter initialEntries={['/dashboard-next']}>
        <AppSwitcher />
      </MemoryRouter>
    )

    // The page loads lazily: allow for a slow first transform
    expect(await screen.findByRole('heading', { name: 'Dashboard' }, { timeout: 5000 })).toBeInTheDocument()
  })
})
