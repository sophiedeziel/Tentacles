import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { MockedProvider } from '@apollo/client/testing/react'
import AppSwitcher from './AppSwitcher'

describe('AppSwitcher', () => {
  it('serves the dashboard at /', async () => {
    render(
      <MockedProvider mocks={[]}>
        <MemoryRouter initialEntries={['/']}>
          <AppSwitcher />
        </MemoryRouter>
      </MockedProvider>
    )

    // The page loads lazily, then fails to load its data (no mocks)
    expect(await screen.findByText('Could not load the dashboard', {}, { timeout: 5000 })).toBeInTheDocument()
  })
})
