import React from 'react'
import { describe, expect, it } from 'vitest'
import { act, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { MockedProvider } from '@apollo/client/testing/react'
import AppSwitcher from './AppSwitcher'
import { GLOBAL_QUEUE_ENABLED } from '../../Sections/Queue/graphql/queue'

// globalQueue is null while the global queue's flag is off. `answered` is called when the switcher gets the answer.
const flag = (on, answered = () => {}) => ({
  request: { query: GLOBAL_QUEUE_ENABLED },
  result: () => {
    answered()
    return { data: { globalQueue: on ? { __typename: 'GlobalQueue', dispatchPaused: false } : null } }
  }
})

const renderAt = (path, mocks = [flag(false)]) => render(
  <MockedProvider mocks={mocks}>
    <MemoryRouter initialEntries={[path]}>
      <AppSwitcher />
    </MemoryRouter>
  </MockedProvider>
)

describe('AppSwitcher', () => {
  it('serves the dashboard at /', async () => {
    renderAt('/')

    // The page loads lazily, then fails to load its data (no mocks)
    expect(await screen.findByText('Could not load the dashboard', {}, { timeout: 5000 })).toBeInTheDocument()
  })

  it('sends the old /dashboard-next address to the dashboard', async () => {
    renderAt('/dashboard-next')

    expect(await screen.findByText('Could not load the dashboard', {}, { timeout: 5000 })).toBeInTheDocument()
  })

  it('serves the global queue at /queue while it is on', async () => {
    renderAt('/queue', [flag(true)])

    // The page loads lazily, then fails to load its data (no mocks)
    expect(await screen.findByText('Could not load the print queue', {}, { timeout: 5000 })).toBeInTheDocument()
  })

  it('has no /queue while the global queue is off', async () => {
    let answered = false
    const { container } = renderAt('/queue', [flag(false, () => { answered = true })])

    await waitFor(() => expect(answered).toBe(true))
    await act(() => new Promise((resolve) => setTimeout(resolve, 50)))
    expect(container).toBeEmptyDOMElement()
  })

  it('serves Add to Queue at /queue/add/:fileId while it is on', async () => {
    renderAt('/queue/add/7', [flag(true)])

    // The page loads lazily, then fails to load its data (no mocks)
    expect(await screen.findByText('Could not load the file', {}, { timeout: 5000 })).toBeInTheDocument()
  })

  it('has no /queue/add/:fileId while the global queue is off', async () => {
    let answered = false
    const { container } = renderAt('/queue/add/7', [flag(false, () => { answered = true })])

    await waitFor(() => expect(answered).toBe(true))
    await act(() => new Promise((resolve) => setTimeout(resolve, 50)))
    expect(container).toBeEmptyDOMElement()
  })
})
