// The Add to Queue form's answers in tests: a G-code summary (bracket_v3.gcode, 18 g and 1 h 10 min of PLA Black a
// copy), its file, the printers and how they fit it, and the queue estimate for a number of copies
export const tool = (overrides = {}) => ({
  __typename: 'GcodeTool', tool: 0, material: 'PLA', materialRaw: 'PLA', colourHex: '#1A1A1A', grams: 18, metres: 6, ...overrides
})
export const summary = (overrides = {}) => ({
  __typename: 'GcodeSummary',
  status: 'READY',
  analysedAt: '2026-11-22T12:00:00Z',
  error: null,
  slicer: 'PrusaSlicer',
  slicerVersion: '2.9.6',
  printSeconds: 4200,
  filamentGrams: 18,
  filamentMetres: 6,
  footprint: {
    __typename: 'GcodeFootprint', width: 120, depth: 80, height: 28, minX: 0, maxX: 120, minY: 0, maxY: 80, source: 'moves'
  },
  toolCount: 1,
  toolChanges: 0,
  tools: [tool()],
  filamentChanges: [],
  ...overrides
})
export const PENDING = summary({ status: 'PENDING', slicer: null, printSeconds: null, footprint: null, toolCount: null, tools: [] })
export const FAILED = summary({ status: 'FAILED', error: 'Unreadable', slicer: null, footprint: null, toolCount: null, tools: [] })
export const file = (gcodeSummary = summary(), overrides = {}) => ({
  __typename: 'File',
  id: '7',
  filename: 'bracket_v3.gcode',
  filesize: 2400000,
  notes: 'Print flat side down, no supports.',
  isDeleted: false,
  gcodeSummary,
  ...overrides
})

export const printer = (id, name, family, loaded) => ({
  __typename: 'Printer',
  id,
  name,
  filamentSlots: 1,
  status: family && { __typename: 'PrinterStatus', stateFamily: family, stateText: family.charAt(0) + family.slice(1).toLowerCase() },
  loadedFilaments: loaded ? [{ __typename: 'LoadedFilament', slot: 1, ...loaded }] : []
})
export const reason = (code, message) => ({ __typename: 'FitReason', code, message })
export const fit = (printerData, result, reasons = [], hardLimit = false) => ({
  __typename: 'PrinterFit', printer: printerData, result, reasons, hardLimit
})
export const MK4 = printer('1', 'Prusa MK4', 'PRINTING', { material: 'PLA', colour: 'Black' })
export const ENDER = printer('2', 'Ender 3 V2', 'OPERATIONAL', { material: 'PLA', colour: 'Black' })
export const VORON = printer('3', 'Voron 2.4', 'PAUSED', { material: 'PETG', colour: 'Grey' })
export const DELTA = printer('5', 'Mini Delta', 'OPERATIONAL', null)

// The fits for the filament asked for: PLA puts the Voron after a filament change; PETG the MK4 and the Ender
export const fitsFor = ({ material }) => [
  fit(MK4, material === 'PETG' ? 'AFTER_FILAMENT_CHANGE' : 'READY'),
  fit(ENDER, material === 'PETG' ? 'AFTER_FILAMENT_CHANGE' : 'READY'),
  fit(VORON, material === 'PETG' ? 'READY' : 'AFTER_FILAMENT_CHANGE'),
  fit(DELTA, 'CANNOT', [reason('BED_TOO_SMALL', 'Bed too small: needs 120 × 80 mm, has a 110 mm round bed')], true)
]

export const estimateFor = ({ copies }) => ({
  __typename: 'QueueEstimate',
  printing: 2,
  waitingJobs: 5,
  jobsAhead: 5,
  printsAhead: 15,
  copiesToPrint: copies,
  filaments: [{ __typename: 'EstimatedFilament', tool: 0, material: 'PLA', colour: 'Black', grams: 18 * copies, metres: 6 * copies }],
  filamentGrams: 18 * copies,
  filamentMetres: 6 * copies,
  printSeconds: 4200 * copies,
  starts: {
    __typename: 'WhatHappensNext',
    kind: 'AFTER_CURRENT_PRINT',
    printer: { __typename: 'Printer', id: '1', name: 'Prusa MK4' },
    jobsAhead: 7,
    dispatchPaused: false,
    startsAt: null
  }
})
