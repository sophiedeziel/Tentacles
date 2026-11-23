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
export const loaded = (material, colour, slot = 1) => ({ __typename: 'LoadedFilament', slot, material, colour })

// The job a printer takes next (QueuePrinterFields' takesNext)
export const takesNext = ({ id, copies = 1, copiesLeftToStart = 1, file: { id: fileId, filename } }) => ({
  __typename: 'PrintJob', id, copies, copiesLeftToStart, file: { __typename: 'File', id: fileId, filename }
})

// An Available Printers row (QueuePrinterFields), its bed clear
const queuePrinter = (printer, extra = {}) => fleetPrinter(printer, {
  takesJobs: true, loadedFilaments: [loaded('PLA', 'Black')], takesNext: null, printOnBed: null, ...extra
})

const CLIPS = file('21', 'cable_clip.gcode')
const BRACKET = file('22', 'bracket.gcode')
const PHONE_STAND = file('20', 'phone_stand.gcode')

// The print still on a printer's bed (QueuePrinterFields' printOnBed)
export const printOnBed = ({ id, jobId, copies = 1, jobFile, copyNumber = 1, result = 'COMPLETED' }) => ({
  __typename: 'Print', id, copyNumber, result, printJob: { __typename: 'PrintJob', id: jobId, copies, file: jobFile }
})

export const MK4 = fleetPrinter(PRINTERS.PRINTING, { loadedFilaments: [loaded('PETG', 'Grey')] })
// Its bed holds bracket.gcode, failed (the queue's finished print 33)
export const MINI = queuePrinter(PRINTERS.OPERATIONAL, {
  takesNext: takesNext({ id: '11', file: PHONE_STAND }),
  printOnBed: printOnBed({ id: '33', jobId: '14', jobFile: BRACKET, result: 'FAILED' })
})
export const VORON_ZERO = queuePrinter({ ...PRINTERS.OPERATIONAL, id: '9', name: 'Voron 0.2', nextJob: null })
export const KOBRA = fleetPrinter(PRINTERS.OFFLINE)

// A copy handed to a printer (QueuePrintFields)
// (`jobPrints`, `copiesLeftToStart`, `samePrinter`: its print job's copies, which a Printing row brings for the copies dialog)
export const print = ({ id, printer, jobId, copies = 1, jobFile, copyNumber = 1, status = 'ACTIVE', progress = 0, result = null, finishedAt = null, copiesLeftToStart = 0, jobPrints = [], samePrinter = false }) => ({
  __typename: 'Print',
  id,
  copyNumber,
  status,
  progress,
  startedAt: '2026-11-14T12:00:00Z',
  finishedAt,
  result,
  printer,
  printJob: { __typename: 'PrintJob', id: jobId, copies, samePrinter, copiesLeftToStart, file: jobFile, prints: jobPrints }
})

const what = (kind, printer = null, more = {}) => ({
  __typename: 'WhatHappensNext', kind, printer: printer && ref(printer), jobsAhead: 0, dispatchPaused: false, ...more
})
export { what as whatHappensNext }

// A waiting print job (QueuePrintJobFields): one copy of phone_stand.gcode in PLA Black, lined up for the Mini once
// its bed is cleared
export const waitingJob = (overrides = {}) => ({
  __typename: 'PrintJob',
  id: '11',
  copies: 1,
  position: 1,
  held: false,
  samePrinter: false,
  allCapable: true,
  copiesLeftToStart: 1,
  file: PHONE_STAND,
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
  whatHappensNext: what('AFTER_BED_CLEARED', MINI),
  prints: [],
  ...overrides
})

const copy = (id, copyNumber, printer, more = {}) => ({
  __typename: 'Print', id, copyNumber, status: 'COMPLETED', progress: 100, result: 'COMPLETED',
  finishedAt: '2026-11-14T12:30:00Z', printer: ref(printer), ...more
})

// A same-printer batch of 3 bound to the MK4: copy 1 done, copy 2 printing, one left to start
export const BATCH = waitingJob({
  id: '12',
  copies: 3,
  position: 2,
  samePrinter: true,
  allCapable: false,
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
  whatHappensNext: what('BATCH_ON_PRINTER', MK4),
  prints: [
    copy('31', 1, MK4),
    copy('32', 2, MK4, { status: 'ACTIVE', progress: 40, result: null, finishedAt: null })
  ]
})

export const HELD = waitingJob({
  id: '13',
  position: 3,
  held: true,
  file: file('23', 'lid.gcode'),
  whatHappensNext: what('ON_HOLD')
})

// Every section filled: the Mini waits for its bed (bracket.gcode failed on it), the Voron 0.2 is free, the Kobra is
// offline, the MK4 prints copy 2 of the batch
export const queue = (overrides = {}) => ({
  __typename: 'GlobalQueue',
  dispatchPaused: false,
  printersToClear: [MINI],
  availablePrinters: [VORON_ZERO],
  offlinePrinters: [KOBRA],
  printing: [print({
    id: '32', printer: MK4, jobId: '12', copies: 3, samePrinter: true, jobFile: CLIPS, copyNumber: 2, progress: 40, copiesLeftToStart: 1, jobPrints: BATCH.prints
  })],
  waiting: [waitingJob(), BATCH, HELD],
  finished: [
    print({ id: '33', printer: MINI, jobId: '14', jobFile: BRACKET, status: 'ERROR', result: 'FAILED', finishedAt: '2026-11-14T13:00:00Z' }),
    print({ id: '31', printer: MK4, jobId: '12', copies: 3, samePrinter: true, jobFile: CLIPS, status: 'COMPLETED', progress: 100, result: 'COMPLETED', finishedAt: '2026-11-14T12:30:00Z' })
  ],
  ...overrides
})

// Nothing waiting, printing or to clear
export const EMPTY_QUEUE = queue({ printersToClear: [], printing: [], waiting: [], finished: [] })
