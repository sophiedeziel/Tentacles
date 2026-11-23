import React from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { print } from 'graphql'
import { App } from 'antd'

import UpdateFile from 'graphql/UpdateFile.graphql'
import GcodeSummary, { POLL_INTERVAL } from './GcodeSummary'
import { GCODE_SUMMARY, REANALYSE_GCODE } from './graphql/gcodeSummary'

const tool = (overrides = {}) => ({
  __typename: 'GcodeTool',
  tool: 0,
  material: 'PLA',
  materialRaw: 'PLA',
  colourHex: '#FF8800',
  grams: 12.4,
  metres: 4.05,
  ...overrides
})
const summary = (overrides = {}) => ({
  __typename: 'GcodeSummary',
  status: 'READY',
  analysedAt: '2026-11-22T12:00:00Z',
  error: null,
  slicer: 'PrusaSlicer',
  slicerVersion: '2.9.6',
  printSeconds: 3720,
  filamentGrams: 12.4,
  filamentMetres: 4.05,
  footprint: {
    __typename: 'GcodeFootprint',
    width: 182,
    depth: 96.04,
    height: 48,
    minX: 10,
    maxX: 192,
    minY: 20,
    maxY: 116.04,
    source: 'moves'
  },
  toolCount: 1,
  toolChanges: 0,
  tools: [tool()],
  filamentChanges: [],
  ...overrides
})
const UNKNOWN = {
  slicer: null,
  slicerVersion: null,
  printSeconds: null,
  filamentGrams: null,
  filamentMetres: null,
  footprint: null,
  toolCount: null,
  toolChanges: null,
  tools: []
}
const PENDING = { ...summary(UNKNOWN), status: 'PENDING', analysedAt: null }
const FAILED = { ...summary(UNKNOWN), status: 'FAILED', error: 'Not a G-code file' }

const summaryMock = (gcodeSummary, delay = 10) => ({
  request: { query: GCODE_SUMMARY, variables: { fileId: '1' } },
  result: { data: { file: { __typename: 'File', id: '1', gcodeSummary } } },
  delay
})
const reanalyseMock = (result) => ({
  request: { query: REANALYSE_GCODE, variables: { input: { fileId: '1' } } },
  delay: 10,
  ...result
})
const payload = (file, errors = []) => ({
  result: { data: { reanalyseGcode: { __typename: 'ReanalyseGcodePayload', file, errors } } }
})
const reanalysed = (gcodeSummary) => payload({ __typename: 'File', id: '1', gcodeSummary })

const renderSummary = (mocks) => {
  const onLineSelect = vi.fn()
  const view = render(
    <MockedProvider cache={new InMemoryCache()} mocks={mocks}>
      <App><GcodeSummary fileId="1" onLineSelect={onLineSelect} /></App>
    </MockedProvider>
  )
  return { ...view, onLineSelect }
}

// The value cell of one row of the details
const row = (label) => screen.getByText(label, { selector: 'th *, th' }).closest('tr').querySelector('td')
const ready = () => screen.findByText('Print time')

// Polling runs on setTimeout: fake it, and let real time drive the mocks' short delays
const fakeTimers = () => vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'], shouldAdvanceTime: true })
const nextPoll = () => act(() => vi.advanceTimersByTimeAsync(POLL_INTERVAL))

describe('GcodeSummary', () => {
  afterEach(() => vi.useRealTimers())

  it('renders nothing for a file that is not G-code', async () => {
    const { container } = renderSummary([summaryMock(null)])
    const app = container.querySelector('.ant-app')
    expect(app.querySelector('.ant-skeleton')).toBeInTheDocument()
    await waitFor(() => expect(app).toBeEmptyDOMElement())
  })

  it('shows the print details of a single-tool file', async () => {
    renderSummary([summaryMock(summary())])
    await ready()
    expect(row('Print time')).toHaveTextContent('1 h 2 min')
    expect(row('Filament')).toHaveTextContent(/^12\.4 g · 4\.05 m\s*PLA · 12\.4 g · 4\.05 m$/)
    expect(within(row('Filament')).getByRole('img', { name: 'Colour #FF8800' })).toHaveStyle({ background: '#FF8800' })
    expect(within(row('Filament')).queryByText('T0')).not.toBeInTheDocument()
    expect(row('Footprint')).toHaveTextContent(/^182 × 96 mm\s*Height 48 mm$/)
    expect(row('Tools')).toHaveTextContent('1 used · 0 changes')
    expect(row('Filament changes')).toHaveTextContent(/^None$/)
    expect(row('Slicer')).toHaveTextContent(/^PrusaSlicer 2\.9\.6$/)
    expect(screen.queryByText('Not known')).not.toBeInTheDocument()
  })

  it('labels each tool of a multi-tool file and links each filament change to its line', async () => {
    const { onLineSelect } = renderSummary([summaryMock(summary({
      printSeconds: 1828,
      filamentGrams: 30.25,
      filamentMetres: 10.1,
      footprint: { ...summary().footprint, width: 120.46, depth: 80, height: 12.25 },
      toolCount: 2,
      toolChanges: 3,
      tools: [tool(), tool({ tool: 1, material: 'PETG', materialRaw: 'PETG', colourHex: '0000ff', grams: 17.85, metres: 6.054 })],
      filamentChanges: [
        { __typename: 'GcodeFilamentChange', line: 1234, z: 5.4, layer: 27 },
        { __typename: 'GcodeFilamentChange', line: 2345, z: 10.2, layer: null },
        { __typename: 'GcodeFilamentChange', line: 3456, z: null, layer: null }
      ]
    }))])
    await ready()
    expect(row('Print time')).toHaveTextContent('30 min 28 s')
    expect(row('Filament')).toHaveTextContent(
      /^30\.3 g · 10\.10 m\s*T0\s*PLA · 12\.4 g · 4\.05 m\s*T1\s*PETG · 17\.9 g · 6\.05 m$/
    )
    expect(within(row('Filament')).getByRole('img', { name: 'Colour #0000ff' })).toBeInTheDocument()
    expect(row('Footprint')).toHaveTextContent(/^120\.5 × 80 mm\s*Height 12\.3 mm$/)
    expect(row('Tools')).toHaveTextContent('2 used · 3 changes')

    await userEvent.click(screen.getByRole('button', { name: 'Layer 27 (Z 5.4 mm)' }))
    expect(onLineSelect).toHaveBeenCalledWith(1234)
    await userEvent.click(screen.getByRole('button', { name: 'Z 10.2 mm' }))
    expect(onLineSelect).toHaveBeenCalledWith(2345)
    await userEvent.click(screen.getByRole('button', { name: 'Line 3456' }))
    expect(onLineSelect).toHaveBeenLastCalledWith(3456)
    expect(onLineSelect).toHaveBeenCalledTimes(3)
  })

  describe('unknown values', () => {
    it('reads Not known in grey for every unknown row, and None for no filament changes', async () => {
      renderSummary([summaryMock(summary(UNKNOWN))])
      await ready()
      for (const label of ['Print time', 'Filament', 'Footprint', 'Tools', 'Slicer']) {
        const cell = row(label)
        expect(cell).toHaveTextContent(/^Not known$/)
        expect(within(cell).getByText('Not known')).toHaveClass('ant-typography-secondary')
      }
      expect(row('Filament changes')).toHaveTextContent(/^None$/)
    })

    it('reads Not known for each unknown value next to the known ones', async () => {
      renderSummary([summaryMock(summary({
        filamentGrams: null,
        footprint: { ...summary().footprint, height: null },
        toolCount: 2,
        toolChanges: null,
        slicerVersion: null,
        tools: [
          tool({ grams: null }),
          tool({ tool: 1, material: null, materialRaw: null, colourHex: null, grams: 3, metres: null }),
          tool({ tool: 2, grams: null, metres: null })
        ]
      }))])
      await ready()
      expect(row('Filament')).toHaveTextContent(new RegExp(
        '^Not known · 4\\.05 m\\s*T0\\s*PLA · Not known · 4\\.05 m' +
        '\\s*T1\\s*Colour not known ·\\s*Not known · 3\\.0 g · Not known\\s*T2\\s*PLA · Not known$'
      ))
      expect(row('Footprint')).toHaveTextContent(/^182 × 96 mm\s*Height Not known$/)
      expect(row('Tools')).toHaveTextContent(/^2 used · Not known$/)
      expect(row('Slicer')).toHaveTextContent(/^PrusaSlicer \(version not known\)$/)
      screen.getAllByText('Not known').forEach((text) => expect(text).toHaveClass('ant-typography-secondary'))
      expect(screen.getByText('Colour not known')).toHaveClass('ant-typography-secondary')
    })

    it('shows no swatch for a tool without a colour', async () => {
      renderSummary([summaryMock(summary({ tools: [tool({ colourHex: null })] }))])
      await ready()
      expect(within(row('Filament')).queryByRole('img')).not.toBeInTheDocument()
      expect(within(row('Filament')).getByText('Colour not known')).toBeInTheDocument()
    })

    it('shows a material the queue cannot match in grey, and says so on hover', async () => {
      renderSummary([summaryMock(summary({ tools: [tool({ material: null, materialRaw: 'Generic Silk' })] }))])
      await ready()
      const raw = within(row('Filament')).getByText('Generic Silk')
      expect(raw).toHaveClass('ant-typography-secondary')
      await userEvent.hover(raw)
      expect(await screen.findByRole('tooltip')).toHaveTextContent('Not a material the queue can match')
    })
  })

  it('shows Analysing… while the file is read, asks again every 3 s, then shows the details and stops', async () => {
    fakeTimers()
    // Answers every request once the file is read, counting them
    const readyResult = vi.fn(() => summaryMock(summary()).result)
    renderSummary([
      summaryMock(PENDING),
      summaryMock(PENDING),
      { ...summaryMock(summary()), result: readyResult, maxUsageCount: Number.POSITIVE_INFINITY }
    ])
    expect(await screen.findByText('Analysing…')).toBeInTheDocument()
    expect(document.querySelector('.ant-skeleton')).toBeInTheDocument()

    await nextPoll()
    expect(screen.getByText('Analysing…')).toBeInTheDocument()
    expect(readyResult).not.toHaveBeenCalled()
    await nextPoll()
    expect(await ready()).toBeInTheDocument()
    expect(screen.queryByText('Analysing…')).not.toBeInTheDocument()
    expect(row('Print time')).toHaveTextContent('1 h 2 min')
    expect(readyResult).toHaveBeenCalledTimes(1)

    // And asks no more
    await nextPoll()
    await nextPoll()
    expect(readyResult).toHaveBeenCalledTimes(1)
  })

  describe('when the file could not be read', () => {
    it('says so with the error, and Re-analyse goes back to Analysing… until the details are read', async () => {
      fakeTimers()
      renderSummary([summaryMock(FAILED), reanalyseMock(reanalysed(PENDING)), summaryMock(summary())])
      const alert = await screen.findByRole('alert')
      expect(alert).toHaveClass('ant-alert-warning')
      expect(alert).toHaveTextContent("Couldn't read this file's print details.")
      expect(alert).toHaveTextContent('Not a G-code file')

      await userEvent.click(within(alert).getByRole('button', { name: 'Re-analyse' }))
      expect(await screen.findByText('Analysing…')).toBeInTheDocument()
      expect(screen.queryByRole('alert')).not.toBeInTheDocument()

      await nextPoll()
      expect(await ready()).toBeInTheDocument()
      expect(row('Slicer')).toHaveTextContent('PrusaSlicer 2.9.6')
    })

    it('shows what the server refused as a message, and stays on the warning', async () => {
      renderSummary([summaryMock(FAILED), reanalyseMock(payload(null, [
        { __typename: 'UserError', field: 'fileId', message: 'File not found' }
      ]))])
      await userEvent.click(await screen.findByRole('button', { name: 'Re-analyse' }))
      expect(await screen.findByText('File not found')).toBeInTheDocument()
      await waitFor(() => expect(screen.getByRole('button', { name: /Re-analyse/ })).not.toHaveClass('ant-btn-loading'))
      expect(screen.getByText("Couldn't read this file's print details.")).toBeInTheDocument()
    })

    it('shows a network failure as a message', async () => {
      renderSummary([summaryMock(FAILED), reanalyseMock({ error: new Error('Server unreachable') })])
      await userEvent.click(await screen.findByRole('button', { name: 'Re-analyse' }))
      expect(await screen.findByText('Could not re-analyse the file: Server unreachable')).toBeInTheDocument()
      expect(screen.getByText("Couldn't read this file's print details.")).toBeInTheDocument()
    })
  })

  it('is selected with the same fields by the save, which resets it to PENDING', () => {
    const fragment = (document) => document.definitions.find((definition) => definition.kind === 'FragmentDefinition')
    const updateFile = print(UpdateFile)
    expect(updateFile).toMatch(/gcodeSummary \{\s*\.\.\.GcodeSummaryFields\s*\}/)
    expect(print(fragment(UpdateFile))).toBe(print(fragment(GCODE_SUMMARY)))
  })

  it('says when the details could not be loaded', async () => {
    renderSummary([{ request: { query: GCODE_SUMMARY, variables: { fileId: '1' } }, error: new Error('Boom'), delay: 10 }])
    expect(await screen.findByText('Could not load the print details')).toBeInTheDocument()
    expect(screen.getByText('Boom')).toBeInTheDocument()
  })
})
