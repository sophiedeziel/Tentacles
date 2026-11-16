import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { App } from 'antd'

import PrinterTile from './PrinterTile'
import { ACTIONS } from '../../graphql/actions'
import { StreamVisibilityProvider } from '../../utils/useStreamWhenVisible'
import { ALL_OPTIONS, FIXTURE_NOW, PRINTERS } from './fixtures'

const renderTile = (family, mocks = [], extra = {}) => render(
  <MockedProvider mocks={mocks}>
    <App>
      <StreamVisibilityProvider>
        <PrinterTile size="L" widget={{ printer: { id: PRINTERS[family].id }, options: ALL_OPTIONS }}
          data={{ printersById: { [PRINTERS[family].id]: PRINTERS[family] }, now: FIXTURE_NOW.getTime(), ...extra }} />
      </StreamVisibilityProvider>
    </App>
  </MockedProvider>
)

describe('PrinterTile', () => {
  it('runs the control on its printer and shows the returned error', async () => {
    renderTile('OFFLINE', [{
      request: { query: ACTIONS.connect.document, variables: { printerId: '7' } },
      result: { data: { connectPrinter: { __typename: 'ConnectPrinterPayload', success: false, errors: ['Kobra 2 is not reachable'] } } }
    }])
    await userEvent.click(screen.getByRole('button', { name: 'Connect' }))
    expect(await screen.findByText('Kobra 2 is not reachable')).toBeInTheDocument()
  })

  // Every camera is in the viewport
  const stubVisible = () => vi.stubGlobal('IntersectionObserver', class {
    constructor (callback) { this.callback = callback }
    observe (target) { this.callback([{ target, isIntersecting: true }]) }
    unobserve () {}
    disconnect () {}
  })

  it('says the camera is offline when its stream fails', () => {
    stubVisible()
    renderTile('PRINTING')
    fireEvent.error(screen.getByRole('img', { name: 'Prusa MK4 webcam' }))
    expect(screen.getByText('Camera offline')).toBeInTheDocument()
    expect(screen.queryByText('Live')).not.toBeInTheDocument()
    vi.unstubAllGlobals()
  })

  it('never streams in edit mode', () => {
    stubVisible()
    renderTile('PRINTING', [], { editing: true })
    expect(screen.queryByRole('img', { name: 'Prusa MK4 webcam' })).not.toBeInTheDocument()
    expect(screen.getByText('Webcam stream')).toBeInTheDocument()
    vi.unstubAllGlobals()
  })

  // The edit toolbar sits over the bottom of the widget, where the controls are
  it('hides its controls in edit mode', () => {
    renderTile('PRINTING', [], { editing: true })
    expect(screen.getByText('bracket_v3.gcode')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Pause' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Cancel' })).not.toBeInTheDocument()
  })

  it('shows its controls out of edit mode', () => {
    renderTile('PRINTING', [], { editing: false })
    expect(screen.getByRole('button', { name: 'Pause' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument()
  })

  it('hides Start Next in edit mode', () => {
    renderTile('OPERATIONAL', [], { editing: true })
    expect(screen.getByText('Ready to print')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Start Next' })).not.toBeInTheDocument()
  })

  it('sends the file the user confirmed, so a printer that moved on refuses', async () => {
    renderTile('PRINTING', [{
      request: { query: ACTIONS.pause.document, variables: { printerId: '1', expectedFileName: 'bracket_v3.gcode' } },
      result: { data: { pausePrint: { __typename: 'PausePrintPayload', success: false, errors: ['Prusa MK4 is now printing gear_v2.gcode'] } } }
    }])
    await userEvent.click(screen.getByRole('button', { name: 'Pause' }))
    await userEvent.click(await screen.findByRole('button', { name: 'Pause Print' }))
    expect(await screen.findByText('Prusa MK4 is now printing gear_v2.gcode')).toBeInTheDocument()
  })

  it('sends the next job the user confirmed', async () => {
    renderTile('OPERATIONAL', [{
      request: { query: ACTIONS.startNext.document, variables: { printerId: '4', expectedJobId: 'spool_holder.gcode' } },
      result: { data: { startNextPrint: { __typename: 'StartNextPrintPayload', success: false, errors: ['Queue changed'] } } }
    }])
    await userEvent.click(screen.getByRole('button', { name: 'Start Next' }))
    await userEvent.click(await screen.findByRole('button', { name: 'Start Print' }))
    expect(await screen.findByText('Queue changed')).toBeInTheDocument()
  })
})
