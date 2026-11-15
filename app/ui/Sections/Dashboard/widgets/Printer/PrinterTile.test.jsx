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

const renderTile = (family, mocks = []) => render(
  <MockedProvider mocks={mocks}>
    <App>
      <StreamVisibilityProvider>
        <PrinterTile size="L" widget={{ printer: { id: PRINTERS[family].id }, options: ALL_OPTIONS }}
          data={{ printersById: { [PRINTERS[family].id]: PRINTERS[family] }, now: FIXTURE_NOW.getTime() }} />
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

  it('says the camera is offline when its stream fails', () => {
    vi.stubGlobal('IntersectionObserver', class {
      constructor (callback) { this.callback = callback }
      observe (target) { this.callback([{ target, isIntersecting: true }]) }
      unobserve () {}
      disconnect () {}
    })
    renderTile('PRINTING')
    fireEvent.error(screen.getByRole('img', { name: 'Prusa MK4 webcam' }))
    expect(screen.getByText('Camera offline')).toBeInTheDocument()
    expect(screen.queryByText('Live')).not.toBeInTheDocument()
    vi.unstubAllGlobals()
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
