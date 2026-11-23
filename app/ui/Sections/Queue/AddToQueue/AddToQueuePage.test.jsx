import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { MemoryRouter, Route, Routes } from 'react-router'
import { App } from 'antd'

import AddToQueuePage from './AddToQueuePage'
import QueueJobForm from './QueueJobForm'
import { ADD_PRINT_JOB, ADD_TO_QUEUE_FILE, PRINTER_FITS, QUEUE_ESTIMATE } from './graphql/addToQueue'
import { FAILED, PENDING, estimateFor, file, fitsFor, summary, tool } from './fixtures'

const always = { maxUsageCount: Number.POSITIVE_INFINITY }

// A server answering every fits and estimate request, and addToQueue with `saveResult`. `calls` records what was asked.
const server = ({ fileData = file(), saveResult = { success: true, errors: [] } } = {}) => {
  const calls = { fits: [], estimates: [], saves: [] }
  const mocks = [
    {
      request: { query: ADD_TO_QUEUE_FILE, variables: { fileId: '7' } },
      result: { data: { file: fileData, filamentMaterials: ['PLA', 'PETG', 'ABS'], filamentColours: ['Black', 'White', 'Grey', 'Red'] } },
      ...always
    },
    {
      request: { query: PRINTER_FITS, variables: () => true },
      result: (variables) => {
        calls.fits.push(variables)
        return { data: { printerFits: fitsFor(variables) } }
      },
      ...always
    },
    {
      request: { query: QUEUE_ESTIMATE, variables: () => true },
      result: (variables) => {
        calls.estimates.push(variables)
        return { data: { queueEstimate: estimateFor(variables) } }
      },
      ...always
    },
    {
      request: { query: ADD_PRINT_JOB, variables: () => true },
      result: (variables) => {
        calls.saves.push(variables)
        return {
          data: {
            addToQueue: {
              __typename: 'AddToQueuePayload',
              printJob: saveResult.success ? { __typename: 'PrintJob', id: '40' } : null,
              ...saveResult,
              errors: saveResult.errors.map((message) => ({ __typename: 'UserError', field: null, message }))
            }
          }
        }
      },
      ...always
    }
  ]
  return { calls, mocks }
}

const renderPage = (options) => {
  const { calls, mocks } = server(options)
  render(
    <MockedProvider cache={new InMemoryCache()} mocks={mocks}>
      <MemoryRouter initialEntries={['/queue/add/7']}>
        <Routes>
          <Route path="/queue" element={<div>The queue page</div>} />
          <Route path="/queue/add/:fileId" element={<AddToQueuePage />} />
        </Routes>
      </MemoryRouter>
    </MockedProvider>
  )
  return calls
}

// The form alone, for a file whose summary changes under it
const renderForm = (fileData) => {
  const { calls, mocks } = server({ fileData })
  const form = (data) => (
    <MockedProvider cache={new InMemoryCache()} mocks={mocks}>
      <MemoryRouter>
        <App>
          <QueueJobForm file={data} materials={['PLA', 'PETG']} colours={['Black', 'Grey', 'Red']}
            submitLabel={() => 'Add to Queue'} onSubmit={async () => true} onCancel={() => {}} />
        </App>
      </MemoryRouter>
    </MockedProvider>
  )
  const view = render(form(fileData))
  return { calls, rerender: (data) => view.rerender(form(data)) }
}

const section = (name) => screen.getByRole('region', { name })
const printerRow = (name) => screen.getByRole('checkbox', { name }).closest('li')
// What a Select shows: its value's label, null while it shows its placeholder
const shown = (label) => screen.getByLabelText(label).closest('.ant-select-content-has-value')?.title ?? null
const pick = async (label, option) => {
  await userEvent.click(screen.getByLabelText(label))
  await userEvent.click(await screen.findByTitle(option, { selector: '.ant-select-item-option' }))
}
const loaded = async () => {
  await screen.findByRole('heading', { name: 'Add to Queue' })
  await within(await screen.findByRole('region', { name: 'Printers' })).findByText('3 of 3 selected')
  await within(section('Summary')).findByText('2 printing · 5 jobs waiting')
}
const setCopies = async (count) => {
  const input = screen.getByRole('spinbutton', { name: 'Copies' })
  await userEvent.clear(input)
  await userEvent.type(input, String(count))
}

describe('AddToQueuePage', () => {
  it('shows the file, its notes and the copies', async () => {
    renderPage()
    await loaded()

    const card = section('File and Copies')
    expect(within(card).getByText('bracket_v3.gcode')).toBeInTheDocument()
    expect(within(card).getByText(/PrusaSlicer · 2\.4/)).toBeInTheDocument()
    expect(within(card).getByRole('spinbutton', { name: 'Copies' })).toHaveValue('1')
    expect(within(card).getByText('Notes on this file')).toBeInTheDocument()
    expect(within(card).getByText('Print flat side down, no supports.')).toBeInTheDocument()
    expect(screen.getByText('Say what the print needs. The queue finds the printers.')).toBeInTheDocument()
  })

  it('prefills the filament from the G-code, the hex read as the nearest named colour', async () => {
    renderPage()
    await loaded()

    expect(shown('Material')).toBe('PLA')
    expect(shown('Colour')).toBe('Black')
    const card = section('Filament')
    expect(within(card).getByText('From the G-code')).toBeInTheDocument()
    expect(within(card).getByText('From the G-code. Any Colour lets more printers take it')).toBeInTheDocument()
    expect(within(card).getByRole('img', { name: "The G-code's colour, #1A1A1A" })).toBeInTheDocument()
    expect(within(card).getByText('120 × 80 × 28 mm')).toBeInTheDocument()
    expect(within(card).queryByText(/°C/)).not.toBeInTheDocument()
  })

  it('brings back the G-code value with the reset button', async () => {
    const calls = renderPage()
    await loaded()

    const reset = screen.getByRole('button', { name: "Reset material to the G-code's" })
    expect(reset).toBeDisabled()
    await pick('Material', 'PETG')
    expect(shown('Material')).toBe('PETG')
    expect(screen.getByText('The G-code says PLA')).toBeInTheDocument()
    await waitFor(() => expect(calls.fits.at(-1)).toEqual({ fileId: '7', material: 'PETG', colour: 'Black' }))

    await userEvent.click(reset)
    expect(shown('Material')).toBe('PLA')
    expect(reset).toBeDisabled()
  })

  it('offers Any Colour, saved as null', async () => {
    const calls = renderPage()
    await loaded()

    await pick('Colour', 'Any Colour')
    expect(screen.getByText('Any colour is accepted. The G-code says Black')).toBeInTheDocument()
    await waitFor(() => expect(calls.fits.at(-1)).toEqual({ fileId: '7', material: 'PLA', colour: null }))
  })

  it('shows a raw material outside the closed list as a hint, the field empty', async () => {
    renderPage({ fileData: file(summary({ tools: [tool({ material: null, materialRaw: 'PCTG', colourHex: null })] })) })
    await loaded()

    expect(shown('Material')).toBeNull()
    expect(shown('Colour')).toBeNull()
    expect(screen.getByText('The G-code says PCTG, which is not a material the queue can match')).toBeInTheDocument()
  })

  it('leaves the fields empty when the G-code could not be read', async () => {
    renderPage({ fileData: file(FAILED) })
    await loaded()

    expect(shown('Material')).toBeNull()
    expect(shown('Colour')).toBeNull()
    expect(screen.getByText(/The G-code couldn't be read/)).toBeInTheDocument()
  })

  it('fills only the empty fields once a pending summary is read, never the ones the person set', async () => {
    const { calls, rerender } = renderForm(file(PENDING))
    await screen.findByText('3 of 3 selected')
    expect(shown('Material')).toBeNull()
    expect(screen.getAllByText('Reading the G-code…')).toHaveLength(2)

    await pick('Colour', 'Red')
    const asked = calls.fits.length
    rerender(file(summary()))

    await waitFor(() => expect(shown('Material')).toBe('PLA'))
    expect(shown('Colour')).toBe('Red')
    // The fits are asked again for the summary read
    await waitFor(() => expect(calls.fits.length).toBeGreaterThan(asked))
  })

  it('lists every printer with its fit, the ones it can print on selected and the others disabled', async () => {
    renderPage()
    await loaded()

    expect(within(printerRow('Prusa MK4')).getByText('Can print it. PLA Black loaded')).toBeInTheDocument()
    expect(within(printerRow('Prusa MK4')).getByText('Printing')).toBeInTheDocument()
    expect(within(printerRow('Voron 2.4')).getByText('Can print it after a filament change. PETG Grey loaded')).toBeInTheDocument()
    expect(within(printerRow('Mini Delta'))
      .getByText("Can't print it: bed too small: needs 120 × 80 mm, has a 110 mm round bed")).toBeInTheDocument()
    expect(screen.getByRole('checkbox', { name: 'Prusa MK4' })).toBeChecked()
    expect(screen.getByRole('checkbox', { name: 'Voron 2.4' })).toBeChecked()
    expect(screen.getByRole('checkbox', { name: 'Mini Delta' })).not.toBeChecked()
    expect(screen.getByRole('checkbox', { name: 'Mini Delta' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Select All' })).toBeDisabled()
  })

  it("keeps the person's ticks when the fits are recomputed", async () => {
    const calls = renderPage()
    await loaded()

    await userEvent.click(screen.getByRole('checkbox', { name: 'Ender 3 V2' }))
    expect(screen.getByText('2 of 3 selected')).toBeInTheDocument()
    await pick('Material', 'PETG')
    await waitFor(() => expect(within(printerRow('Voron 2.4')).getByText('Can print it. PETG Grey loaded')).toBeInTheDocument())

    expect(screen.getByRole('checkbox', { name: 'Ender 3 V2' })).not.toBeChecked()
    expect(screen.getByRole('checkbox', { name: 'Prusa MK4' })).toBeChecked()
    await waitFor(() => expect(calls.estimates.at(-1)).toMatchObject({ material: 'PETG', printerIds: ['1', '3'] }))
  })

  it('clears and selects all', async () => {
    renderPage()
    await loaded()

    await userEvent.click(screen.getByRole('button', { name: 'Clear' }))
    expect(screen.getByText('0 of 3 selected')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Add to Queue' })).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: 'Select All' }))
    expect(screen.getByText('3 of 3 selected')).toBeInTheDocument()
  })

  it('sums up the queue, when it starts, the filament and the print time', async () => {
    renderPage()
    await loaded()
    await setCopies(10)

    const summaryCard = section('Summary')
    // The total, and the line of its one filament
    await waitFor(() => expect(within(summaryCard).getAllByText('180 g · 60 m')).toHaveLength(2))
    expect(within(summaryCard).getByText('Ahead of this job: 5 jobs · 15 prints')).toBeInTheDocument()
    expect(within(summaryCard).getByText('Prusa MK4, after 7 jobs ahead of it')).toBeInTheDocument()
    expect(within(summaryCard).getByText('PLA · Black')).toBeInTheDocument()
    expect(within(summaryCard).getByText('11 h 40 min')).toBeInTheDocument()
    expect(within(summaryCard).getByText('All copies, about 5 h 50 min on 2 printers at once')).toBeInTheDocument()
    expect(within(summaryCard).getByRole('button', { name: 'Add 10 Prints to Queue' })).toBeInTheDocument()

    await userEvent.click(screen.getByRole('switch', { name: 'Keep all copies on the same printer' }))
    expect(await within(summaryCard).findByText('All copies, one after another')).toBeInTheDocument()
  })

  it('asks for one estimate once the copies settle, not one per keystroke', async () => {
    const calls = renderPage()
    await loaded()
    const asked = calls.estimates.length

    await setCopies(25)

    await waitFor(() => expect(calls.estimates.at(-1)).toMatchObject({ copies: 25 }))
    // Typing "25" goes through 2 copies on the way: it's never asked for
    expect(calls.estimates.slice(asked).map((variables) => variables.copies)).not.toContain(2)
  })

  it('saves no material for a file with several filaments: each is the material its G-code says', async () => {
    const twoTools = summary({ toolCount: 2, tools: [tool(), tool({ tool: 1, material: 'PETG', materialRaw: 'PETG' })] })
    const calls = renderPage({ fileData: file(twoTools) })
    await loaded()

    expect(screen.getByText('Several filaments: each one is the material its G-code says')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Add to Queue' }))

    await screen.findByText('The queue page')
    expect(calls.saves[0].material).toBeNull()
    expect(calls.fits.at(-1).material).toBeNull()
  })

  it('saves the untouched selection as every printer that can print it, then goes back to the queue', async () => {
    const calls = renderPage()
    await loaded()

    await userEvent.click(screen.getByText('Next Up'))
    await userEvent.click(screen.getByRole('switch', { name: 'Hold until I release it' }))
    await userEvent.click(screen.getByRole('button', { name: 'Add to Queue' }))

    expect(await screen.findByText('The queue page')).toBeInTheDocument()
    expect(calls.saves).toEqual([{
      fileId: '7', copies: 1, material: 'PLA', colour: 'Black', samePrinter: false, printerIds: null, position: 'TOP', held: true
    }])
  })

  it('saves the list of printers once the person changed it', async () => {
    const calls = renderPage()
    await loaded()

    await userEvent.click(screen.getByRole('checkbox', { name: 'Voron 2.4' }))
    await userEvent.click(screen.getByRole('button', { name: 'Add to Queue' }))

    await screen.findByText('The queue page')
    expect(calls.saves[0].printerIds).toEqual(['1', '2'])
  })

  it('stays on the form and shows why when the server refuses', async () => {
    const calls = renderPage({ saveResult: { success: false, errors: ["Mini Delta can't print it: Bed too small"] } })
    await loaded()

    await userEvent.click(screen.getByRole('button', { name: 'Add to Queue' }))

    expect(await screen.findByText("Mini Delta can't print it: Bed too small")).toBeInTheDocument()
    expect(calls.saves).toHaveLength(1)
    expect(screen.queryByText('The queue page')).not.toBeInTheDocument()
    // (jsdom never ends the loading icon's leave motion, which stays in the name)
    await waitFor(() => expect(screen.getByRole('button', { name: /Add to Queue$/ })).toBeEnabled())
  })

  it('goes back to the queue on Cancel', async () => {
    renderPage()
    await loaded()

    await userEvent.click(screen.getByRole('button', { name: 'Cancel' }))
    expect(await screen.findByText('The queue page')).toBeInTheDocument()
  })

  it('says so for a file that is not G-code', async () => {
    renderPage({ fileData: file(null) })

    expect(await screen.findByText('Only G-code files can be queued')).toBeInTheDocument()
  })
})
