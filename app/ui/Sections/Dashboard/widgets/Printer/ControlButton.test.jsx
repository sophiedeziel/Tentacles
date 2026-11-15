import React from 'react'
import { describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { App } from 'antd'

import ControlButton from './ControlButton'
import printerView from './printerView'
import { ALL_OPTIONS, FIXTURE_NOW, PRINTERS } from './fixtures'

const setup = (family, key, onRun = vi.fn().mockResolvedValue([]), live = true) => {
  const view = printerView({ printer: PRINTERS[family], size: 'L', options: ALL_OPTIONS, now: FIXTURE_NOW })
  const action = view.actions.find((candidate) => candidate.key === key)
  render(<App><ControlButton action={action} view={view} onRun={onRun} live={live} /></App>)
  return onRun
}

describe('ControlButton', () => {
  it('asks in a Popconfirm before pausing', async () => {
    const onRun = setup('PRINTING', 'pause')
    await userEvent.click(screen.getByRole('button', { name: 'Pause' }))
    expect(await screen.findByText('Pause this print?')).toBeInTheDocument()
    expect(screen.getByText('Prusa MK4 parks the print head at 64% and keeps the bed warm.')).toBeInTheDocument()
    expect(onRun).not.toHaveBeenCalled()

    await userEvent.click(screen.getByRole('button', { name: 'Pause Print' }))
    expect(onRun).toHaveBeenCalledWith('pause')
  })

  it('keeps printing when the Popconfirm is dismissed', async () => {
    const onRun = setup('PRINTING', 'pause')
    await userEvent.click(screen.getByRole('button', { name: 'Pause' }))
    await userEvent.click(await screen.findByRole('button', { name: 'Keep Printing' }))
    expect(onRun).not.toHaveBeenCalled()
  })

  it('names the file before starting the next print', async () => {
    const onRun = setup('OPERATIONAL', 'startNext')
    await userEvent.click(screen.getByRole('button', { name: 'Start Next' }))
    expect(await screen.findByText('spool_holder.gcode starts on Prusa Mini+. Make sure the bed is clear.')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Start Print' }))
    expect(onRun).toHaveBeenCalledWith('startNext')
  })

  it('asks in a Modal before cancelling, since it cannot be undone', async () => {
    const onRun = setup('PAUSED', 'cancel')
    await userEvent.click(screen.getByRole('button', { name: 'Cancel' }))
    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('Cancel this print?')
    expect(dialog).toHaveTextContent('enclosure_panel.gcode stops at 38% and can’t be resumed. The file stays in your library.')
    expect(screen.getByRole('button', { name: 'Keep Paused' })).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Cancel Print' }))
    expect(onRun).toHaveBeenCalledWith('cancel')
  })

  it('connects right away and shows the errors it returns', async () => {
    const onRun = setup('OFFLINE', 'connect', vi.fn().mockResolvedValue(["Could not reach Kobra 2's OctoPrint"]))
    await userEvent.click(screen.getByRole('button', { name: 'Connect' }))
    expect(onRun).toHaveBeenCalledWith('connect')
    expect(await screen.findByText("Could not reach Kobra 2's OctoPrint")).toBeInTheDocument()
  })

  it('spins until the mutation resolves', async () => {
    let resolve
    setup('ERROR', 'reconnect', vi.fn(() => new Promise((done) => { resolve = done })))
    const button = screen.getByRole('button', { name: 'Reconnect' })
    await userEvent.click(button)
    await waitFor(() => expect(button).toHaveClass('ant-btn-loading'))
    resolve([])
    await waitFor(() => expect(button).not.toHaveClass('ant-btn-loading'))
  })

  it('runs the Modal OK once, and keeps the Modal open until the mutation resolves', async () => {
    let resolve
    const onRun = setup('PRINTING', 'cancel', vi.fn(() => new Promise((done) => { resolve = done })))
    await userEvent.click(screen.getByRole('button', { name: 'Cancel' }))
    const ok = await screen.findByRole('button', { name: 'Cancel Print' })
    await userEvent.click(ok)
    await userEvent.click(ok)
    expect(onRun).toHaveBeenCalledTimes(1)
    expect(screen.getByRole('dialog')).not.toHaveClass('ant-zoom-leave')

    resolve([])
    // It closes (antd keeps it mounted while it animates out)
    await waitFor(() => expect(screen.getByRole('dialog')).toHaveClass('ant-zoom-leave'))
  })

  it('warns that states may be out of date when the dashboard is not live', async () => {
    setup('PRINTING', 'pause', vi.fn().mockResolvedValue([]), false)
    await userEvent.click(screen.getByRole('button', { name: 'Pause' }))
    expect(await screen.findByText(/keeps the bed warm\. Printer states may be out of date\.$/)).toBeInTheDocument()
  })
})
