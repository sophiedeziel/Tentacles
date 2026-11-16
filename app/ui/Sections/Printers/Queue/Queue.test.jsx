import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { MemoryRouter, Route, Routes } from 'react-router'

import Queue from './Queue'
import PrinterSubscription from './graphql/PrinterSubscription.graphql'

const job = (id, status, filename) => ({
  __typename: 'EnqueuedJobEdge',
  node: {
    __typename: 'EnqueuedJob',
    id,
    status,
    progress: status === 'completed' ? 100 : 0,
    createdAt: '2026-11-15T10:00:00Z',
    executable: { __typename: 'File', filename }
  }
})

const renderPage = (edges) => render(
  <MockedProvider mocks={[{
    request: { query: PrinterSubscription, variables: { id: '3' } },
    result: {
      data: {
        printerSubscription: {
          __typename: 'PrinterSubscriptionPayload',
          printer: { __typename: 'Printer', name: 'Prusa MK4', jobs: { __typename: 'EnqueuedJobConnection', edges } }
        }
      }
    }
  }]}>
    <MemoryRouter initialEntries={['/printers/3/queue']}>
      <Routes>
        <Route path="/printers/:id/queue" element={<Queue />} />
        <Route path="/files" element={<p>Files page</p>} />
      </Routes>
    </MemoryRouter>
  </MockedProvider>
)

describe('Queue', () => {
  it('says the queue is empty, and sends to Files to queue prints', async () => {
    renderPage([])

    expect(await screen.findByText('Queue is empty')).toBeInTheDocument()
    expect(screen.getByText('Send G-code from Files to queue prints for this printer.')).toBeInTheDocument()
    expect(screen.queryByText(/Enqueued/)).not.toBeInTheDocument()
    expect(screen.queryByText(/History/)).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Go to Files' }))
    expect(screen.getByText('Files page')).toBeInTheDocument()
  })

  it('keeps the history under an empty queue', async () => {
    renderPage([job('1', 'completed', 'benchy.gcode')])

    expect(await screen.findByText('Queue is empty')).toBeInTheDocument()
    expect(screen.getByText('History (1)')).toBeInTheDocument()
    expect(screen.getByText('benchy.gcode')).toBeInTheDocument()
  })

  it('lists the enqueued jobs', async () => {
    renderPage([job('2', 'enqueued', 'calibration-cube.gcode')])

    expect(await screen.findByText('Enqueued (1)')).toBeInTheDocument()
    expect(screen.getAllByText('calibration-cube.gcode')).not.toHaveLength(0)
    expect(screen.queryByText('Queue is empty')).not.toBeInTheDocument()
  })
})
