import React from 'react'
import PropTypes from 'prop-types'
import { describe, expect, it } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { App, Button } from 'antd'

import { bedClearedText, useBedCleared } from '.'
import { CONFIRM_BED_CLEARED } from '../graphql/actions'

const BRACKET = { copies: 10, copiesLeftToStart: 7, file: { filename: 'bracket_v3.gcode' } }

describe('bedClearedText', () => {
  const words = (extra) => bedClearedText({ printerName: 'Ender 3 V2', takesNext: BRACKET, ...extra })

  it('asks whether the bed is clear, and says the printer starts with the copy it takes next', () => {
    expect(words()).toEqual({
      title: 'Is the bed of Ender 3 V2 clear?',
      body: 'It starts printing as soon as it can pick a job from the queue. Next for it: bracket_v3.gcode, copy 4 of 10.',
      check: 'Check that the part and any leftover filament are off the bed first.'
    })
  })

  it('names a single print without a copy, and nothing when nothing is lined up', () => {
    expect(words({ takesNext: { ...BRACKET, copies: 1, copiesLeftToStart: 1 } }).body)
      .toBe('It starts printing as soon as it can pick a job from the queue. Next for it: bracket_v3.gcode.')
    expect(words({ takesNext: null }).body).toBe('It starts printing as soon as it can pick a job from the queue.')
  })

  it('says a printer not taking jobs won’t start the next one', () => {
    expect(words({ takesJobs: false }).body).toBe("Ender 3 V2 isn't taking jobs from the queue, so it won't start the next one.")
    expect(words({ takesJobs: false, dispatchPaused: true }).body)
      .toBe("Ender 3 V2 isn't taking jobs from the queue, so it won't start the next one.")
  })

  it('says nothing starts while dispatch is paused', () => {
    expect(words({ dispatchPaused: true }).body)
      .toBe('Dispatch is paused, so it will not start yet. It picks a job from the queue as soon as you resume dispatch.')
  })
})

// A page with one printer to clear, as the printer page uses it. `printOnBed`: the print its bed holds, as the page
// shows it now
function Page ({ onDone, dispatchPaused = false, printOnBed = { id: '31' } }) {
  const bedCleared = useBedCleared({ dispatchPaused, onDone })
  const printer = { id: '1', name: 'Prusa MK4', takesJobs: true, takesNext: { ...BRACKET, copiesLeftToStart: 10 }, printOnBed }
  return (
    <>
      <Button onClick={() => bedCleared.ask(printer)}>Bed Cleared</Button>
      {bedCleared.modal}
    </>
  )
}

Page.propTypes = { onDone: PropTypes.func, dispatchPaused: PropTypes.bool, printOnBed: PropTypes.object }

// The page, answering confirmBedCleared for print 31 with `result`: what was sent, and `rerender(props)` to show the
// page again with other props
const renderPage = (result, props = {}) => {
  const sent = []
  const variables = { printerId: '1', expectedPrintId: '31' }
  const page = (pageProps) => (
    <MockedProvider mocks={[{
      request: { query: CONFIRM_BED_CLEARED, variables },
      result: () => {
        sent.push(variables)
        return { data: { confirmBedCleared: { __typename: 'ConfirmBedClearedPayload', ...result } } }
      }
    }]}>
      <App><Page {...pageProps} /></App>
    </MockedProvider>
  )
  const { rerender } = render(page(props))
  return { sent, rerender: (newProps) => rerender(page(newProps)) }
}

describe('useBedCleared', () => {
  it('opens the modal for a printer, confirms, then runs onDone', async () => {
    let done = 0
    const { sent } = renderPage({ success: true, errors: [] }, { onDone: () => { done += 1 } })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('Is the bed of Prusa MK4 clear?')
    expect(dialog).toHaveTextContent('Next for it: bracket_v3.gcode, copy 1 of 10.')
    expect(dialog).toHaveTextContent('Check that the part and any leftover filament are off the bed first.')

    await userEvent.click(within(dialog).getByRole('button', { name: 'Bed Is Clear' }))
    await waitFor(() => expect(sent).toEqual([{ printerId: '1', expectedPrintId: '31' }]))
    await waitFor(() => expect(done).toBe(1))
  })

  it('says dispatch is paused', async () => {
    renderPage({ success: true, errors: [] }, { dispatchPaused: true })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    expect(await screen.findByRole('dialog'))
      .toHaveTextContent('Dispatch is paused, so it will not start yet.')
  })

  it('sends nothing when the person has not cleared it yet', async () => {
    const { sent } = renderPage({ success: true, errors: [] })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Not Yet' }))
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(sent).toEqual([])
  })

  it('clears the print it was opened for, even when the page shows a newer one since', async () => {
    const { sent, rerender } = renderPage({ success: true, errors: [] })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    const dialog = await screen.findByRole('dialog')
    rerender({ printOnBed: { id: '32' } })
    await userEvent.click(within(dialog).getByRole('button', { name: 'Bed Is Clear' }))
    await waitFor(() => expect(sent).toEqual([{ printerId: '1', expectedPrintId: '31' }]))
  })

  it('shows why the server refused (the bed now holds another print), then reloads', async () => {
    let done = 0
    const refusal = "Prusa MK4's bed now holds another print: bracket_v3.gcode, copy 3 of 10. Check it before clearing the bed."
    renderPage({ success: false, errors: [{ __typename: 'UserError', field: null, message: refusal }] }, { onDone: () => { done += 1 } })

    await userEvent.click(screen.getByRole('button', { name: 'Bed Cleared' }))
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Bed Is Clear' }))
    expect(await screen.findByText(refusal)).toBeInTheDocument()
    await waitFor(() => expect(done).toBe(1))
  })
})
