import React from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { MemoryRouter, useLocation } from 'react-router'

import QueuePage from './QueuePage'
import { FINISHED_ROWS, GLOBAL_QUEUE_PAGE, QUEUE_CHANGED } from './graphql/queue'
import {
  ADD_TO_QUEUE, CONFIRM_BED_CLEARED, HOLD_PRINT_JOB, MOVE_PRINT_JOB, PAUSE_DISPATCH, RELEASE_PRINT_JOB,
  REMOVE_PRINT_JOB, RESUME_DISPATCH, SET_PRINT_JOB_COPIES, UNBIND_PRINT_JOB
} from './graphql/actions'
import { ACTIONS } from '../Dashboard/graphql/actions'
import { POSSIBLE_TYPES, PRINT_QUEUE_CHANGED, PRINTER_STATUS_CHANGED, TYPE_POLICIES } from '../Dashboard/graphql/dashboard'
import { BATCH, HELD, KOBRA, MINI, MK4, print, printOnBed, queue, waitingJob } from './fixtures'

const later = { delay: 60000 }
const always = { maxUsageCount: Number.POSITIVE_INFINITY }

// The page's query answers `pages` in turn (the first load, then each reload), the last one from then on
const pageMocks = (pages) => pages.map((globalQueue, index) => ({
  request: { query: GLOBAL_QUEUE_PAGE, variables: { finished: FINISHED_ROWS } },
  result: { data: { globalQueue } },
  ...(index === pages.length - 1 ? always : {})
}))

const renderPage = (pages, mocks = []) => render(
  <MockedProvider cache={new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })} mocks={[
    ...pageMocks(Array.isArray(pages) ? pages : [pages]),
    { request: { query: PRINTER_STATUS_CHANGED }, result: { data: { printerStatusChanged: MK4 } }, ...later },
    { request: { query: PRINT_QUEUE_CHANGED }, result: { data: { printQueueChanged: null } }, ...later },
    { request: { query: QUEUE_CHANGED }, result: { data: { queueChanged: { __typename: 'QueueChange', dispatchPaused: false } } }, ...later },
    ...mocks
  ]}>
    <MemoryRouter initialEntries={['/queue']}><QueuePage /><CurrentPath /></MemoryRouter>
  </MockedProvider>
)

function CurrentPath () {
  return <span data-testid="path">{useLocation().pathname}</span>
}

const refused = (message) => [{ __typename: 'UserError', field: null, message }]

// A mutation the server answers: `sent` lists the variables of each request. `payload` completes the answer
// (the fields the document selects besides success and errors); `errors` makes it a refusal.
function mutation (query, field, variables, { payload = {}, errors = [], ...options } = {}) {
  const sent = []
  const mock = {
    request: { query, variables },
    result: () => {
      sent.push(variables)
      return { data: { [field]: { __typename: 'Payload', success: errors.length === 0, errors, ...payload } } }
    },
    ...options
  }
  return { sent, mock }
}

const section = (name) => screen.getByRole('region', { name })
const rows = (name) => within(section(name)).getAllByRole('row').filter((row) => row.dataset.rowKey)
const row = (name, key) => rows(name).find((each) => each.dataset.rowKey === key)
// The Waiting rows' keys, in order (not a batch's copies, in their own table under it)
const order = () => {
  const table = section('Waiting').querySelector('.ant-table-wrapper')
  return rows('Waiting').filter((each) => each.closest('.ant-table-wrapper') === table).map((each) => each.dataset.rowKey)
}
const loaded = () => screen.findByRole('heading', { name: 'Print Queue' })

// The menu just opened (antd keeps the ones closed before, hidden)
const openMenu = async (rowElement) => {
  await userEvent.click(within(rowElement).getByRole('button', { name: /^More actions for/ }))
  return (await screen.findAllByRole('menu')).at(-1)
}
const menuItems = (menu) => within(menu).getAllByRole('menuitem').map((item) => item.textContent)
const pick = async (rowElement, label) => userEvent.click(within(await openMenu(rowElement)).getByText(label))

// The queue with its waiting jobs in another order, as the server answers after a move
const reordered = (ids) => {
  const jobs = queue().waiting
  return queue({ waiting: ids.map((id) => jobs.find((job) => job.id === id)) })
}

describe('reordering the Waiting rows', () => {
  // jsdom lays nothing out: each Waiting row is 60 px high, one under the other, so the keyboard can move a row
  // over the next one
  beforeEach(() => {
    vi.spyOn(Element.prototype, 'getBoundingClientRect').mockImplementation(function () {
      const keyed = this.closest?.('tr[data-row-key]')
      const index = keyed ? [...keyed.parentElement.querySelectorAll(':scope > tr[data-row-key]')].indexOf(keyed) : -1
      const top = Math.max(index, 0) * 60
      return { x: 0, y: top, top, left: 0, right: 800, bottom: top + 60, width: 800, height: 60, toJSON: () => ({}) }
    })
  })
  afterEach(() => vi.restoreAllMocks())

  // Picks a row up by its handle, moves it down `steps` rows and drops it, with the keyboard
  const moveDown = async (filename, steps) => {
    const handle = screen.getByRole('button', { name: `Drag ${filename}` })
    handle.focus()
    await userEvent.keyboard(' ')
    for (let step = 0; step < steps; step += 1) {
      await act(async () => { fireEvent.keyDown(document.activeElement, { code: 'ArrowDown', key: 'ArrowDown' }) })
    }
    await act(async () => { fireEvent.keyDown(document.activeElement, { code: 'Space', key: ' ' }) })
  }

  it('moves the row at once, then sends movePrintJob with the row it now sits above', async () => {
    const move = mutation(MOVE_PRINT_JOB, 'movePrintJob', { id: '11', beforeId: '13' }, { delay: 100 })
    renderPage([queue(), reordered(['12', '11', '13'])], [move.mock])
    await loaded()
    expect(order()).toEqual(['11', '12', '13'])

    await moveDown('phone_stand.gcode', 1)

    expect(order()).toEqual(['12', '11', '13'])
    expect(within(row('Waiting', '11')).getAllByRole('cell')[1]).toHaveTextContent('2')
    await waitFor(() => expect(move.sent).toEqual([{ id: '11', beforeId: '13' }]))
    await waitFor(() => expect(order()).toEqual(['12', '11', '13']))
  })

  it('keeps a moved row in its place while another row is dragged, even when the move answered meanwhile', async () => {
    const move = mutation(MOVE_PRINT_JOB, 'movePrintJob', { id: '11', beforeId: '13' }, { delay: 100 })
    renderPage([queue(), reordered(['12', '11', '13'])], [move.mock])
    await loaded()

    await moveDown('phone_stand.gcode', 1)
    // Another row is picked up before the move answered: the page holds the queue it showed before the move
    screen.getByRole('button', { name: 'Drag lid.gcode' }).focus()
    await userEvent.keyboard(' ')
    await waitFor(() => expect(move.sent).toHaveLength(1))
    await act(() => new Promise((resolve) => setTimeout(resolve, 100)))
    expect(order()).toEqual(['12', '11', '13'])

    await act(async () => { fireEvent.keyDown(document.activeElement, { code: 'Escape', key: 'Escape' }) })
    expect(order()).toEqual(['12', '11', '13'])
  })

  it('puts the row back and says why when the server refuses the move', async () => {
    const move = mutation(MOVE_PRINT_JOB, 'movePrintJob', { id: '11', beforeId: '13' }, {
      errors: refused('lid.gcode is no longer in the queue'), delay: 100
    })
    renderPage(queue(), [move.mock])
    await loaded()

    await moveDown('phone_stand.gcode', 1)
    expect(order()).toEqual(['12', '11', '13'])

    expect(await screen.findByText('lid.gcode is no longer in the queue')).toBeInTheDocument()
    await waitFor(() => expect(order()).toEqual(['11', '12', '13']))
  })

  it('puts the row back when the move fails on the way', async () => {
    renderPage(queue(), [{
      request: { query: MOVE_PRINT_JOB, variables: { id: '11', beforeId: '13' } }, error: new Error('Network down')
    }])
    await loaded()

    await moveDown('phone_stand.gcode', 1)

    expect(await screen.findByText('Move failed: Network down')).toBeInTheDocument()
    await waitFor(() => expect(order()).toEqual(['11', '12', '13']))
  })

  it('drags a batch as one row: its copies fold away while it moves', async () => {
    renderPage(queue())
    await loaded()
    await userEvent.click(within(row('Waiting', BATCH.id)).getByRole('button', { name: 'Show the copies of cable_clip.gcode' }))
    const copies = () => screen.getByRole('group', { name: 'Copies of cable_clip.gcode', hidden: true })
    expect(copies()).toBeVisible()
    // The copies have no handle of their own
    expect(within(section('Waiting')).getAllByRole('button', { name: /^Drag / })).toHaveLength(3)

    const handle = screen.getByRole('button', { name: 'Drag cable_clip.gcode' })
    handle.focus()
    await userEvent.keyboard(' ')
    expect(copies()).not.toBeVisible()

    await act(async () => { fireEvent.keyDown(document.activeElement, { code: 'Escape', key: 'Escape' }) })
    expect(copies()).toBeVisible()
    expect(order()).toEqual(['11', '12', '13'])
  })
})

it('reorders only with every job shown', async () => {
  renderPage(queue())
  await loaded()

  await userEvent.click(within(section('Waiting')).getByText('On Hold'))

  expect(screen.getByRole('button', { name: 'Drag lid.gcode' })).toBeDisabled()
})

describe('the Waiting ⋯ menu', () => {
  it('lists what each waiting job allows, as the MoreMenu frame draws it', async () => {
    renderPage(queue())
    await loaded()

    expect(menuItems(await openMenu(row('Waiting', '11')))).toEqual([
      'Move to Top', 'Move to Bottom', 'Hold', 'Print More Copies', 'Open File', 'Remove from Queue'
    ])
    await userEvent.keyboard('{Escape}')
    expect(menuItems(await openMenu(row('Waiting', BATCH.id)))).toEqual([
      'Move to Top', 'Move to Bottom', 'Hold', 'Change Number of Copies', 'Show Copies', 'Release to Other Printers',
      'Open File', 'Remove from Queue'
    ])
    await userEvent.keyboard('{Escape}')
    expect(menuItems(await openMenu(row('Waiting', HELD.id)))).toContain('Release')
  })

  it('disables moving the first row up and the last row down', async () => {
    renderPage(queue())
    await loaded()

    const first = await openMenu(row('Waiting', '11'))
    expect(within(first).getByRole('menuitem', { name: /Move to Top/ })).toHaveAttribute('aria-disabled', 'true')
    expect(within(first).getByRole('menuitem', { name: /Move to Bottom/ })).not.toHaveAttribute('aria-disabled', 'true')
  })

  it.each([
    ['13', 'Move to Top', MOVE_PRINT_JOB, 'movePrintJob', { id: '13', to: 'TOP' }, {}],
    ['11', 'Move to Bottom', MOVE_PRINT_JOB, 'movePrintJob', { id: '11', to: 'BOTTOM' }, {}],
    ['13', 'Release', RELEASE_PRINT_JOB, 'releasePrintJob', { id: '13' }, { printJob: null }],
    ['12', 'Release to Other Printers', UNBIND_PRINT_JOB, 'unbindPrintJob', { id: '12' }, { printJob: null }]
  ])('on row %s, %s sends its mutation', async (key, label, query, field, variables, payload) => {
    const sent = mutation(query, field, variables, { payload })
    renderPage(queue(), [sent.mock])
    await loaded()

    await pick(row('Waiting', key), label)

    await waitFor(() => expect(sent.sent).toEqual([variables]))
  })

  it('shows a batch’s copies', async () => {
    renderPage(queue())
    await loaded()
    expect(screen.queryByRole('group', { name: 'Copies of cable_clip.gcode' })).not.toBeInTheDocument()

    await pick(row('Waiting', BATCH.id), 'Show Copies')

    expect(await screen.findByRole('group', { name: 'Copies of cable_clip.gcode' })).toBeVisible()
  })

  it('opens the file', async () => {
    renderPage(queue())
    await loaded()

    await pick(row('Waiting', '11'), 'Open File')

    expect(screen.getByTestId('path')).toHaveTextContent('/files/20')
  })

  it('releases a held job from its What Happens Next', async () => {
    const release = mutation(RELEASE_PRINT_JOB, 'releasePrintJob', { id: HELD.id }, { payload: { printJob: null } })
    renderPage(queue(), [release.mock])
    await loaded()

    await userEvent.click(within(row('Waiting', HELD.id)).getByRole('button', { name: 'Release' }))

    await waitFor(() => expect(release.sent).toEqual([{ id: HELD.id }]))
  })

  it('releases a bound batch to other printers from its copies', async () => {
    const unbind = mutation(UNBIND_PRINT_JOB, 'unbindPrintJob', { id: '12' }, { payload: { printJob: null } })
    renderPage(queue(), [unbind.mock])
    await loaded()
    await userEvent.click(within(row('Waiting', BATCH.id)).getByRole('button', { name: 'Show the copies of cable_clip.gcode' }))

    const copies = screen.getByRole('group', { name: 'Copies of cable_clip.gcode' })
    await userEvent.click(within(copies).getByRole('button', { name: 'Release to Other Printers' }))

    await waitFor(() => expect(unbind.sent).toEqual([{ id: '12' }]))
  })

  it('shows why the server refused, then reloads', async () => {
    const hold = mutation(HOLD_PRINT_JOB, 'holdPrintJob', { id: '11' }, {
      payload: { printJob: null }, errors: refused('phone_stand.gcode is no longer in the queue')
    })
    renderPage([queue(), queue({ waiting: [BATCH, HELD] })], [hold.mock])
    await loaded()

    await pick(row('Waiting', '11'), 'Hold')

    expect(await screen.findByText('phone_stand.gcode is no longer in the queue')).toBeInTheDocument()
    await waitFor(() => expect(order()).toEqual(['12', '13']))
  })

  it('removes the waiting copies after a confirmation naming the file and the copies', async () => {
    const remove = mutation(REMOVE_PRINT_JOB, 'removePrintJob', { id: '12' }, { payload: { deletedPrintJobId: null } })
    renderPage(queue(), [remove.mock])
    await loaded()

    await pick(row('Waiting', BATCH.id), 'Remove from Queue')

    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('Remove cable_clip.gcode from the queue?')
    expect(dialog).toHaveTextContent(
      'The copy waiting to start is removed. The copy printing now finishes. The file stays in your library.'
    )
    expect(remove.sent).toEqual([])
    await userEvent.click(within(dialog).getByRole('button', { name: 'Remove from Queue' }))
    await waitFor(() => expect(remove.sent).toEqual([{ id: '12' }]))
  })

  it('removes nothing when the confirmation is dismissed', async () => {
    const remove = mutation(REMOVE_PRINT_JOB, 'removePrintJob', { id: '11' }, { payload: { deletedPrintJobId: '11' } })
    renderPage(queue(), [remove.mock])
    await loaded()

    await pick(row('Waiting', '11'), 'Remove from Queue')
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Keep in Queue' }))

    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(remove.sent).toEqual([])
  })
})

describe('the copies dialog', () => {
  const total = () => screen.getByRole('spinbutton', { name: 'Total copies' })

  it('changes the number of copies of a batch, never below the copies done and printing', async () => {
    const save = mutation(SET_PRINT_JOB_COPIES, 'setPrintJobCopies', { id: '12', copies: 5 }, { payload: { printJob: null } })
    renderPage(queue(), [save.mock])
    await loaded()

    await pick(row('Waiting', BATCH.id), 'Change Number of Copies')

    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('Change the number of copies of cable_clip.gcode')
    expect(dialog).toHaveTextContent('The lowest is 2: 1 copy is done and 1 is printing, and those can\'t be taken back.')
    expect(total()).toHaveAttribute('aria-valuemin', '2')
    expect(total()).toHaveValue('3')
    expect(within(dialog).getByRole('button', { name: 'Set to 3 Copies' })).toBeDisabled()

    await userEvent.tripleClick(total())
    await userEvent.keyboard('5')
    expect(dialog).toHaveTextContent('Adds 2 copies to the 1 waiting.')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Set to 5 Copies' }))

    await waitFor(() => expect(save.sent).toEqual([{ id: '12', copies: 5 }]))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
  })

  it('prints more copies of a single print', async () => {
    const save = mutation(SET_PRINT_JOB_COPIES, 'setPrintJobCopies', { id: '11', copies: 2 }, { payload: { printJob: null } })
    renderPage(queue(), [save.mock])
    await loaded()

    await pick(row('Waiting', '11'), 'Print More Copies')

    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('Print more copies of phone_stand.gcode')
    expect(dialog).toHaveTextContent('Now 1 copy. 1 more will be added.')
    expect(dialog).toHaveTextContent('The job becomes a batch.')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Print 2 Copies' }))

    await waitFor(() => expect(save.sent).toEqual([{ id: '11', copies: 2 }]))
  })

  it('stays open and shows why when the server refuses', async () => {
    const save = mutation(SET_PRINT_JOB_COPIES, 'setPrintJobCopies', { id: '11', copies: 2 }, {
      payload: { printJob: null }, errors: refused('phone_stand.gcode is no longer in the queue')
    })
    renderPage(queue(), [save.mock])
    await loaded()

    await pick(row('Waiting', '11'), 'Print More Copies')
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Print 2 Copies' }))

    expect(await screen.findByText('phone_stand.gcode is no longer in the queue')).toBeInTheDocument()
    expect(screen.getByRole('dialog')).toBeInTheDocument()
  })

  it('opens from a copy printing, for its print job', async () => {
    renderPage(queue())
    await loaded()

    await pick(row('Printing', '32'), 'Change Number of Copies')

    expect(await screen.findByRole('dialog')).toHaveTextContent('Change the number of copies of cable_clip.gcode')
    expect(total()).toHaveAttribute('aria-valuemin', '2')
  })
})

describe('the dispatch switch and banner', () => {
  it('pauses dispatch, then shows the state reloaded', async () => {
    const pause = mutation(PAUSE_DISPATCH, 'pauseDispatch', {})
    renderPage([queue(), queue({ dispatchPaused: true })], [pause.mock])
    await loaded()

    await userEvent.click(screen.getByRole('switch', { name: 'Dispatch' }))

    await waitFor(() => expect(pause.sent).toEqual([{}]))
    await waitFor(() => expect(screen.getByRole('switch', { name: 'Dispatch' })).not.toBeChecked())
    expect(screen.getByText('Dispatch is paused')).toBeInTheDocument()
  })

  it('resumes dispatch', async () => {
    const resume = mutation(RESUME_DISPATCH, 'resumeDispatch', {})
    renderPage([queue({ dispatchPaused: true }), queue()], [resume.mock])
    await loaded()

    await userEvent.click(screen.getByRole('switch', { name: 'Dispatch' }))

    await waitFor(() => expect(resume.sent).toEqual([{}]))
    await waitFor(() => expect(screen.getByRole('switch', { name: 'Dispatch' })).toBeChecked())
  })

  it('resumes dispatch from the banner', async () => {
    const resume = mutation(RESUME_DISPATCH, 'resumeDispatch', {})
    renderPage([queue({ dispatchPaused: true }), queue()], [resume.mock])
    await loaded()

    await userEvent.click(within(screen.getByRole('alert')).getByRole('button', { name: 'Resume Dispatch' }))

    await waitFor(() => expect(resume.sent).toEqual([{}]))
    await waitFor(() => expect(screen.queryByText('Dispatch is paused')).not.toBeInTheDocument())
  })

  it('stays as it was and says why when the server refuses', async () => {
    const pause = mutation(PAUSE_DISPATCH, 'pauseDispatch', {}, { errors: refused('The global print queue is off') })
    renderPage(queue(), [pause.mock])
    await loaded()

    await userEvent.click(screen.getByRole('switch', { name: 'Dispatch' }))

    expect(await screen.findByText('The global print queue is off')).toBeInTheDocument()
    expect(screen.getByRole('switch', { name: 'Dispatch' })).toBeChecked()
  })
})

describe('the Printing ⋯ menu', () => {
  // The MK4, paused: the batch's copy 2 is on it
  const PAUSED = { ...MK4, status: { ...MK4.status, stateFamily: 'PAUSED', stateText: 'Paused' } }
  const CLIPS = BATCH.file
  const pausedQueue = () => queue({
    printing: [print({
      id: '32', printer: PAUSED, jobId: '12', copies: 3, jobFile: CLIPS, copyNumber: 2, progress: 40, copiesLeftToStart: 1, jobPrints: BATCH.prints
    })],
    // Not the MK4's finished copy: its printer's status would say printing
    finished: [queue().finished[0]]
  })
  const printing = (key = '32') => row('Printing', key)

  it('offers what the MoreMenu frame draws for a batch’s copy', async () => {
    renderPage(queue())
    await loaded()

    expect(within(printing()).queryByRole('button', { name: /Pause|Cancel/ })).not.toBeInTheDocument()
    expect(menuItems(await openMenu(printing()))).toEqual([
      'Pause Print', 'Change Number of Copies', 'Show Batch in Waiting', 'Open File', 'Open Printer', 'Cancel Print'
    ])
  })

  it('offers Resume while paused', async () => {
    renderPage(pausedQueue())
    await loaded()

    expect(menuItems(await openMenu(printing()))).toEqual(expect.arrayContaining(['Resume Print', 'Cancel Print']))
    expect(menuItems((await screen.findAllByRole('menu')).at(-1))).not.toContain('Pause Print')
  })

  it('offers Print More Copies on a single print', async () => {
    const single = print({ id: '40', printer: MK4, jobId: '99', jobFile: { __typename: 'File', id: '50', filename: 'knob.gcode', isDeleted: false } })
    renderPage(queue({ printing: [single], waiting: [waitingJob()] }))
    await loaded()

    expect(menuItems(await openMenu(printing('40'))))
      .toEqual(['Pause Print', 'Print More Copies', 'Open File', 'Open Printer', 'Cancel Print'])
  })

  it('shows the batch in Waiting, its copies expanded', async () => {
    renderPage(queue())
    await loaded()

    await pick(printing(), 'Show Batch in Waiting')

    expect(await screen.findByRole('group', { name: 'Copies of cable_clip.gcode' })).toBeVisible()
  })

  it('opens the printer', async () => {
    renderPage(queue())
    await loaded()

    await pick(printing(), 'Open Printer')

    expect(screen.getByTestId('path')).toHaveTextContent('/printers/1')
  })

  it('pauses the copy, naming the file shown', async () => {
    const pause = mutation(ACTIONS.pause.document, 'pausePrint', { printerId: '1', expectedFileName: 'cable_clip.gcode' })
    renderPage(queue(), [pause.mock])
    await loaded()

    await pick(printing(), 'Pause Print')

    await waitFor(() => expect(pause.sent).toEqual([{ printerId: '1', expectedFileName: 'cable_clip.gcode' }]))
  })

  it('resumes the copy', async () => {
    const resume = mutation(ACTIONS.resume.document, 'resumePrint', { printerId: '1', expectedFileName: 'cable_clip.gcode' })
    renderPage(pausedQueue(), [resume.mock])
    await loaded()

    await pick(printing(), 'Resume Print')

    await waitFor(() => expect(resume.sent).toEqual([{ printerId: '1', expectedFileName: 'cable_clip.gcode' }]))
  })

  it('cancels the copy after a confirmation, sending the file shown as expectedFileName', async () => {
    const cancel = mutation(ACTIONS.cancel.document, 'cancelPrint', { printerId: '1', expectedFileName: 'cable_clip.gcode' })
    renderPage(queue(), [cancel.mock])
    await loaded()

    await pick(printing(), 'Cancel Print')

    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('Cancel this print?')
    expect(dialog).toHaveTextContent('cable_clip.gcode stops at 64% and can’t be resumed.')
    expect(cancel.sent).toEqual([])
    await userEvent.click(within(dialog).getByRole('button', { name: 'Cancel Print' }))
    await waitFor(() => expect(cancel.sent).toEqual([{ printerId: '1', expectedFileName: 'cable_clip.gcode' }]))
  })

  it('shows the printer’s refusal', async () => {
    const pause = mutation(ACTIONS.pause.document, 'pausePrint', { printerId: '1', expectedFileName: 'cable_clip.gcode' }, {
      errors: ['Prusa MK4 is now printing bracket_v3.gcode']
    })
    renderPage(queue(), [pause.mock])
    await loaded()

    await pick(printing(), 'Pause Print')

    expect(await screen.findByText('Prusa MK4 is now printing bracket_v3.gcode')).toBeInTheDocument()
  })
})

describe('Finished', () => {
  it('requeues a failed print: one copy, at the bottom', async () => {
    const requeue = mutation(ADD_TO_QUEUE, 'addToQueue', { fileId: '22', copies: 1 }, { payload: { printJob: null } })
    renderPage(queue(), [requeue.mock])
    await loaded()

    expect(within(row('Finished', '31')).queryByRole('button', { name: /Requeue/ })).not.toBeInTheDocument()
    await userEvent.click(within(row('Finished', '33')).getByRole('button', { name: 'Requeue bracket.gcode' }))

    await waitFor(() => expect(requeue.sent).toEqual([{ fileId: '22', copies: 1 }]))
  })
})

describe('Reconnect on an offline printer', () => {
  it('connects an offline printer again', async () => {
    const connect = mutation(ACTIONS.connect.document, 'connectPrinter', { printerId: '7' })
    renderPage(queue(), [connect.mock])
    await loaded()

    const line = within(section('Available Printers')).getByText('Kobra 2 is offline and takes no jobs.').parentElement
    await userEvent.click(within(line).getByRole('button', { name: 'Reconnect' }))

    await waitFor(() => expect(connect.sent).toEqual([{ printerId: '7' }]))
  })

  it('reconnects a printer in error', async () => {
    const reconnect = mutation(ACTIONS.reconnect.document, 'reconnectPrinter', { printerId: '7' })
    const errored = { ...KOBRA, status: { ...KOBRA.status, stateFamily: 'ERROR', stateText: 'Error' } }
    renderPage(queue({ offlinePrinters: [errored] }), [reconnect.mock])
    await loaded()

    await userEvent.click(within(section('Available Printers')).getByRole('button', { name: 'Reconnect' }))

    await waitFor(() => expect(reconnect.sent).toEqual([{ printerId: '7' }]))
  })
})

describe('Bed Cleared on a printer with its bed to clear', () => {
  const clear = async (pages, mocks) => {
    renderPage(pages, mocks)
    await loaded()
    await userEvent.click(within(row('Available Printers', '4')).getByRole('button', { name: 'Bed Cleared' }))
    return screen.findByRole('dialog')
  }

  it('asks whether the bed is clear, says what the printer takes next, then confirms', async () => {
    const confirm = mutation(CONFIRM_BED_CLEARED, 'confirmBedCleared', { printerId: '4', expectedPrintId: '33' })
    const dialog = await clear([queue(), queue({ printersToClear: [] })], [confirm.mock])

    expect(dialog).toHaveTextContent('Is the bed of Prusa Mini+ clear?')
    expect(dialog).toHaveTextContent(
      'It starts printing as soon as it can pick a job from the queue. Next for it: phone_stand.gcode.'
    )
    expect(dialog).toHaveTextContent('Check that the part and any leftover filament are off the bed first.')
    expect(confirm.sent).toEqual([])

    await userEvent.click(within(dialog).getByRole('button', { name: 'Bed Is Clear' }))
    await waitFor(() => expect(confirm.sent).toEqual([{ printerId: '4', expectedPrintId: '33' }]))
    await waitFor(() => expect(row('Available Printers', '4')).toBeUndefined())
  })

  it('says the printer won’t start yet while dispatch is paused', async () => {
    const dialog = await clear(queue({ dispatchPaused: true }))

    expect(dialog).toHaveTextContent('Dispatch is paused, so it will not start yet.')
  })

  it('shows why the server refused when the bed now holds another print, and reloads to show it', async () => {
    const refusal = "Prusa Mini+'s bed now holds another print: hinge.gcode. Check it before clearing the bed."
    const confirm = mutation(CONFIRM_BED_CLEARED, 'confirmBedCleared', { printerId: '4', expectedPrintId: '33' }, {
      errors: refused(refusal)
    })
    const hinge = { __typename: 'File', id: '25', filename: 'hinge.gcode', isDeleted: false }
    const newer = { ...MINI, printOnBed: printOnBed({ id: '34', jobId: '15', jobFile: hinge }) }
    const dialog = await clear([queue(), queue({ printersToClear: [newer] })], [confirm.mock])

    await userEvent.click(within(dialog).getByRole('button', { name: 'Bed Is Clear' }))
    expect(await screen.findByText(refusal)).toBeInTheDocument()
    expect(await within(row('Available Printers', '4')).findByText('hinge.gcode is finished and still on the bed'))
      .toBeInTheDocument()
  })

  it('offers no Bed Cleared without the print on the bed to name', async () => {
    renderPage(queue({ printersToClear: [{ ...MINI, printOnBed: null }] }))
    await loaded()

    expect(within(row('Available Printers', '4')).queryByRole('button', { name: 'Bed Cleared' })).not.toBeInTheDocument()
  })
})
