import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MockedProvider } from '@apollo/client/testing/react'
import { MemoryRouter, Route, Routes } from 'react-router'

import PrintRedirect from './PrintRedirect'
import { GLOBAL_QUEUE_ENABLED } from '../graphql/queue'

const flag = (on) => ({
  request: { query: GLOBAL_QUEUE_ENABLED },
  result: { data: { globalQueue: on ? { __typename: 'GlobalQueue', dispatchPaused: false } : null } }
})

const renderAt = (mocks) => render(
  <MockedProvider mocks={mocks}>
    <MemoryRouter initialEntries={['/files/7/print']}>
      <Routes>
        <Route path="/files/:id/print" element={<PrintRedirect />} />
        <Route path="/files/:id" element={<p>File page</p>} />
        <Route path="/queue/add/:fileId" element={<p>Add to Queue page</p>} />
      </Routes>
    </MemoryRouter>
  </MockedProvider>
)

describe('PrintRedirect', () => {
  it('sends the old print page to Add to Queue while the queue is on', async () => {
    renderAt([flag(true)])

    expect(await screen.findByText('Add to Queue page')).toBeInTheDocument()
  })

  it("sends it to the file's page while the queue is off", async () => {
    renderAt([flag(false)])

    expect(await screen.findByText('File page')).toBeInTheDocument()
  })

  it('shows neither page until the flag is known', () => {
    const { container } = renderAt([flag(true)])

    expect(container).toBeEmptyDOMElement()
  })
})
