import React from 'react'
import PropTypes from 'prop-types'
import { describe, expect, it } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { App, Button } from 'antd'

import { bedClearedText, useBedCleared } from '.'
import { CONFIRM_BED_CLEARED } from '../graphql/actions'

describe('bedClearedText', () => {
  const words = (extra) => bedClearedText({ printerName: 'Prusa MK4', fileName: 'cube.gcode', ...extra })

  it('asks to check the print and any leftover filament are off the bed, then says the printer takes the next job', () => {
    expect(words()).toEqual({
      title: 'Bed cleared on Prusa MK4?',
      check: 'Check that cube.gcode and any leftover filament are off the bed.',
      next: 'Prusa MK4 can then take the next job in the queue.'
    })
  })

  it('says the last print when the file is not known', () => {
    expect(words({ fileName: null }).check).toBe('Check that the last print and any leftover filament are off the bed.')
  })

  it('says a printer not taking jobs won’t start the next one', () => {
    expect(words({ takesJobs: false }).next).toBe("Prusa MK4 isn't taking jobs, so it won't start the next one.")
    expect(words({ takesJobs: false, dispatchPaused: true }).next)
      .toBe("Prusa MK4 isn't taking jobs, so it won't start the next one.")
  })

  it('says nothing starts while dispatch is paused', () => {
    expect(words({ dispatchPaused: true }).next)
      .toBe("Dispatch is paused, so Prusa MK4 won't start the next job until it resumes.")
  })
})

// A page with one printer to clear, as the printer page uses it
function Page ({ onDone, dispatchPaused = false }) {
  const bedCleared = useBedCleared({ dispatchPaused, onDone })
  const printer = { id: '1', name: 'Prusa MK4', takesJobs: true }
  return (
    <>
      <Button onClick={() => bedCleared.ask(printer, 'cube.gcode')}>Bed Cleared</Button>
      {bedCleared.modal}
    </>
  )
}

Page.propTypes = { onDone: PropTypes.func, dispatchPaused: PropTypes.bool }

const renderPage = (result, props = {}) => {
  const sent = []
  render(
    <MockedProvider mocks={[{
      request: { query: CONFIRM_BED_CLEARED, variables: { printerId: '1' } },
      result: () => {
        sent.push({ printerId: '1' })
        return { data: { confirmBedCleared: { __typename: 'ConfirmBedClearedPayload', ...result } } }
      }
    }]}>
      <App><Page {...props} /></App>
    </MockedProvider>
  )
  return sent
}

describe('useBedCleared', () => {
  it('opens the modal for a printer, confirms, then runs onDone', async () => {
    let done = 0
    const sent = renderPage({ success: true, errors: [] }, { onDone: () => { done += 1 } })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('Bed cleared on Prusa MK4?')
    expect(dialog).toHaveTextContent('Check that cube.gcode and any leftover filament are off the bed.')
    expect(dialog).toHaveTextContent('Prusa MK4 can then take the next job in the queue.')

    await userEvent.click(within(dialog).getByRole('button', { name: 'Bed Cleared' }))
    await waitFor(() => expect(sent).toEqual([{ printerId: '1' }]))
    await waitFor(() => expect(done).toBe(1))
  })

  it('says dispatch is paused', async () => {
    renderPage({ success: true, errors: [] }, { dispatchPaused: true })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    expect(await screen.findByRole('dialog'))
      .toHaveTextContent("Dispatch is paused, so Prusa MK4 won't start the next job until it resumes.")
  })

  it('sends nothing when the person has not cleared it yet', async () => {
    const sent = renderPage({ success: true, errors: [] })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Not Yet' }))
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(sent).toEqual([])
  })

  it('shows why the server refused', async () => {
    renderPage({ success: false, errors: [{ __typename: 'UserError', field: null, message: 'Nothing to clear on Prusa MK4' }] })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Bed Cleared' }))
    expect(await screen.findByText('Nothing to clear on Prusa MK4')).toBeInTheDocument()
  })
})
