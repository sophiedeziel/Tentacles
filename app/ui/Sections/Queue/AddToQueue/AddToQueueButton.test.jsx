import React from 'react'
import { describe, expect, it } from 'vitest'
import { act, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { MemoryRouter, Route, Routes } from 'react-router'

import AddToQueueButton, { queueable } from './AddToQueueButton'
import { GLOBAL_QUEUE_ENABLED } from '../graphql/queue'

// globalQueue is null while the global queue's flag is off. `answered` is called when the button gets the answer.
const flag = (on, answered = () => {}) => ({
  request: { query: GLOBAL_QUEUE_ENABLED },
  result: () => {
    answered()
    return { data: { globalQueue: on ? { __typename: 'GlobalQueue', dispatchPaused: false } : null } }
  }
})

const renderButton = (file, mocks) => render(
  <MockedProvider mocks={mocks}>
    <MemoryRouter initialEntries={[`/files/${file.id}`]}>
      <Routes>
        <Route path="/files/:id" element={<AddToQueueButton file={file} />} />
        <Route path="/queue/add/:fileId" element={<p>Add to Queue page</p>} />
      </Routes>
    </MemoryRouter>
  </MockedProvider>
)

const settle = () => act(() => new Promise((resolve) => setTimeout(resolve, 50)))

describe('AddToQueueButton', () => {
  it('opens Add to Queue for a G-code file while the queue is on', async () => {
    renderButton({ id: '7', filetype: '.gcode' }, [flag(true)])

    await userEvent.click(await screen.findByRole('button', { name: /Add to Queue/ }))

    expect(screen.getByText('Add to Queue page')).toBeInTheDocument()
  })

  it('is not shown for a file the queue cannot print', async () => {
    let answered = false
    renderButton({ id: '7', filetype: '.stl' }, [flag(true, () => { answered = true })])

    await waitFor(() => expect(answered).toBe(true))
    await settle()
    expect(screen.queryByRole('button', { name: /Add to Queue/ })).not.toBeInTheDocument()
  })

  it('is not shown while the queue is off', async () => {
    let answered = false
    renderButton({ id: '7', filetype: '.gcode' }, [flag(false, () => { answered = true })])

    await waitFor(() => expect(answered).toBe(true))
    await settle()
    expect(screen.queryByRole('button', { name: /Add to Queue/ })).not.toBeInTheDocument()
  })

  it('takes G-code files only, whatever the case of the extension', () => {
    expect(queueable({ filetype: '.gcode' })).toBe(true)
    expect(queueable({ filetype: '.GCODE' })).toBe(true)
    expect(queueable({ filetype: '.bgcode' })).toBe(false)
    expect(queueable({ filetype: '.stl' })).toBe(false)
    expect(queueable(null)).toBe(false)
  })
})
