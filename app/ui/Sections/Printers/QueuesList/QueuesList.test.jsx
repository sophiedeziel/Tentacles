import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { MemoryRouter, Route, Routes } from 'react-router'

import QueuesList from './QueuesList'
import Printers from './graphql/Printers.graphql'

const PRINTER = {
  __typename: 'Printer',
  id: '1',
  backend: 'OCTOPRINT',
  uri: 'http://192.168.1.1/',
  jobsCount: 2,
  name: 'Prusa MK4',
  jobStatus: null,
  createdAt: '2026-11-15T10:00:00Z',
  updatedAt: '2026-11-15T10:00:00Z'
}

const renderPage = (printers) => render(
  <MockedProvider mocks={[{ request: { query: Printers }, result: { data: { printers } } }]}>
    <MemoryRouter initialEntries={['/printers/queues']}>
      <Routes>
        <Route path="/printers/queues" element={<QueuesList />} />
        <Route path="/printers/add" element={<p>Add Printer page</p>} />
      </Routes>
    </MemoryRouter>
  </MockedProvider>
)

describe('QueuesList', () => {
  it('invites to add a printer when there is none', async () => {
    renderPage([])

    expect(await screen.findByText('No printers yet')).toBeInTheDocument()
    expect(screen.getByText('Add a printer to give it a print queue.')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: /Add Printer/ }))
    expect(screen.getByText('Add Printer page')).toBeInTheDocument()
  })

  it("links to each printer's queue", async () => {
    renderPage([PRINTER])

    expect(await screen.findByRole('link', { name: 'Prusa MK4' })).toHaveAttribute('href', '/printers/1/queue')
    expect(screen.getByText('2 jobs in queue')).toBeInTheDocument()
    expect(screen.queryByText('No printers yet')).not.toBeInTheDocument()
  })
})
