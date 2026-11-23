// A global queue as the GlobalQueuePage query returns it, for tests. Printers come from the dashboard's fixtures.
import { PRINTERS } from '../Dashboard/widgets/Printer/fixtures'

// A printer with the dashboard's printer fields, typed for the Apollo cache
export const fleetPrinter = (printer, extra = {}) => ({
  __typename: 'Printer',
  ...printer,
  nextJob: printer.nextJob && {
    __typename: 'EnqueuedJob', ...printer.nextJob, executable: { __typename: 'File', ...printer.nextJob.executable }
  },
  status: {
    __typename: 'PrinterStatus',
    ...printer.status,
    hotend: printer.status.hotend && { __typename: 'TemperatureStatus', ...printer.status.hotend },
    bed: printer.status.bed && { __typename: 'TemperatureStatus', ...printer.status.bed },
    camera: { __typename: 'PrinterCamera', ...printer.status.camera }
  },
  ...extra
})

const ref = ({ id, name }) => ({ __typename: 'Printer', id, name })
const file = (id, filename) => ({ __typename: 'File', id, filename, isDeleted: false })
const filament = (tool, material, colour) => ({ __typename: 'NeededFilament', tool, material, colour })

export const MK4 = fleetPrinter(PRINTERS.PRINTING)
export const MINI = fleetPrinter(PRINTERS.OPERATIONAL)
export const VORON_ZERO = fleetPrinter({ ...PRINTERS.OPERATIONAL, id: '9', name: 'Voron 0.2', nextJob: null }, {
  loadedFilaments: [{ __typename: 'LoadedFilament', slot: 1, material: 'PLA', colour: 'Black' }]
})

const CLIPS = file('21', 'cable_clip.gcode')
const BRACKET = file('22', 'bracket.gcode')

// A copy handed to a printer (QueuePrintFields)
export const print = ({ id, printer, jobId, copies = 1, jobFile, copyNumber = 1, status = 'ACTIVE', progress = 0, result = null, finishedAt = null }) => ({
  __typename: 'Print',
  id,
  copyNumber,
  status,
  progress,
  startedAt: '2026-11-14T12:00:00Z',
  finishedAt,
  result,
  printer,
  printJob: { __typename: 'PrintJob', id: jobId, copies, file: jobFile }
})

// A waiting print job (QueuePrintJobFields): one copy of phone_stand.gcode in PLA Black, for the next ready printer
export const waitingJob = (overrides = {}) => ({
  __typename: 'PrintJob',
  id: '11',
  copies: 1,
  position: 1,
  held: false,
  samePrinter: false,
  copiesLeftToStart: 1,
  file: file('20', 'phone_stand.gcode'),
  boundPrinter: null,
  needs: {
    __typename: 'PrintJobNeeds',
    pending: false,
    known: true,
    colour: 'Black',
    filaments: [filament(0, 'PLA', 'Black')],
    footprint: { __typename: 'GcodeFootprint', width: 120, depth: 80 }
  },
  eligiblePrinters: [ref(MINI), ref(VORON_ZERO)],
  whatHappensNext: { __typename: 'WhatHappensNext', kind: 'NEXT_READY_PRINTER', printer: null },
  prints: [],
  ...overrides
})

// A same-printer batch of 3 bound to the MK4: copy 1 done, copy 2 printing, one left to start
export const BATCH = waitingJob({
  id: '12',
  copies: 3,
  position: 2,
  samePrinter: true,
  copiesLeftToStart: 1,
  file: CLIPS,
  boundPrinter: ref(MK4),
  needs: {
    __typename: 'PrintJobNeeds',
    pending: false,
    known: true,
    colour: null,
    filaments: [filament(0, 'PETG', null), filament(1, 'PLA', null)],
    footprint: null
  },
  eligiblePrinters: [ref(MK4)],
  whatHappensNext: { __typename: 'WhatHappensNext', kind: 'BATCH_ON_PRINTER', printer: ref(MK4) },
  prints: [
    { __typename: 'Print', id: '31', copyNumber: 1, status: 'COMPLETED', progress: 100, result: 'COMPLETED', printer: ref(MK4) },
    { __typename: 'Print', id: '32', copyNumber: 2, status: 'ACTIVE', progress: 40, result: null, printer: ref(MK4) }
  ]
})

export const HELD = waitingJob({
  id: '13',
  position: 3,
  held: true,
  file: file('23', 'lid.gcode'),
  whatHappensNext: { __typename: 'WhatHappensNext', kind: 'ON_HOLD', printer: null }
})

// Every section filled: the Mini waits for its bed (bracket.gcode failed on it), the Voron 0.2 is free, the MK4
// prints copy 2 of the batch
export const queue = (overrides = {}) => ({
  __typename: 'GlobalQueue',
  dispatchPaused: false,
  printersToClear: [MINI],
  availablePrinters: [VORON_ZERO],
  printing: [print({ id: '32', printer: MK4, jobId: '12', copies: 3, jobFile: CLIPS, copyNumber: 2, progress: 40 })],
  waiting: [waitingJob(), BATCH, HELD],
  finished: [
    print({ id: '33', printer: MINI, jobId: '14', jobFile: BRACKET, status: 'ERROR', result: 'FAILED', finishedAt: '2026-11-14T13:00:00Z' }),
    print({ id: '31', printer: MK4, jobId: '12', copies: 3, jobFile: CLIPS, status: 'COMPLETED', progress: 100, result: 'COMPLETED', finishedAt: '2026-11-14T12:30:00Z' })
  ],
  ...overrides
})

// Nothing waiting, printing or to clear
export const EMPTY_QUEUE = queue({ printersToClear: [], printing: [], waiting: [], finished: [] })
