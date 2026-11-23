// The printer page's part of the global queue as PrinterDetailsQueue returns it, for tests. Jobs come from the queue
// page's fixtures, with the fields this query selects.
import { BATCH, HELD, waitingJob } from '../../Queue/fixtures'

const file = (id, filename) => ({ __typename: 'File', id, filename, isDeleted: false })

// An Up Next row (PrinterQueueJobFields): the queue page's job without its copies, with its place in the queue
const upNextJob = ({ prints: _prints, position: _position, ...job }, waitingPosition) => ({ ...job, waitingPosition })

// phone_stand.gcode (#1, for the next ready printer), the same-printer batch of 3 with 1 left (#2), lid.gcode held (#4)
export const UP_NEXT = [upNextJob(waitingJob(), 1), upNextJob(BATCH, 2), upNextJob(HELD, 4)]

// vase.gcode (#3), skipped for two reasons
export const SKIPPED = [{
  __typename: 'SkippedPrintJob',
  reasons: ['Limited to Voron 2.4', 'Needs PETG. PLA is loaded here'],
  printJob: { __typename: 'PrintJob', id: '15', waitingPosition: 3, copies: 1, copiesLeftToStart: 1, file: file('25', 'vase.gcode') }
}]

export const PLA_WHITE = { __typename: 'LoadedFilament', slot: 1, material: 'PLA', colour: 'White' }

// Copy 2 of 10 of bracket.gcode, ended as `result`: what is on the printer's bed
export const printOnBed = (result = 'COMPLETED') => ({
  __typename: 'Print',
  id: '40',
  copyNumber: 2,
  result,
  printJob: { __typename: 'PrintJob', id: '14', copies: 10, file: file('22', 'bracket.gcode') }
})

// The Prusa MK4 (id 1): copy 2 of 10 of bracket.gcode on its bed, the same-printer batch (#2, its copy 3 of 3) next
// for it, PLA White loaded (no waiting job asks for it)
export const queuePrinter = (overrides = {}) => ({
  __typename: 'Printer',
  id: '1',
  name: 'Prusa MK4',
  takesJobs: true,
  bedNeedsClearing: true,
  printOnBed: printOnBed(),
  takesNext: { __typename: 'PrintJob', id: '12', copies: 3, copiesLeftToStart: 1, file: file('21', 'cable_clip.gcode') },
  upNext: UP_NEXT,
  skipped: SKIPPED,
  loadedFilaments: [{ ...PLA_WHITE, waitingJobsAskingCount: 0 }],
  ...overrides
})

// What PrinterDetailsQueue answers
export const printerQueue = (printer = queuePrinter(), dispatchPaused = false) => ({
  globalQueue: { __typename: 'GlobalQueue', dispatchPaused },
  printer
})
